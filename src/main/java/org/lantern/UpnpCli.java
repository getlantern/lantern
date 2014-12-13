package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.LogOutputStream;
import org.apache.commons.exec.PumpStreamHandler;
import org.lantern.util.Threads;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.littleshoot.proxy.impl.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 * UPnP implementation that simply calls out to the miniupnp executable.
 */
@Singleton
public class UpnpCli implements UpnpService, Shutdownable {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File exe;
    
    private final Collection<Integer> mappedPorts = new ArrayList<Integer>();
    
    public UpnpCli() {
        this.exe = locateExecutable();
    }

    /**
     * Parallelizes the deletion of all port mappings we've created. Note that
     * this is a blocking operation that will halt after a fixed amount of time.
     */
    private void deleteAllPortMappings() {
        final ExecutorService threadPool = 
                Threads.newCachedThreadPool("UPnP-Shutdown-Thread", false);
        final Collection<Callable<Integer>> tasks = 
                new ArrayList<Callable<Integer>>(mappedPorts.size());
        for (final Integer port : mappedPorts) {
            final Callable<Integer> task = new Callable<Integer>() {
                @Override
                public Integer call() throws Exception {
                    deletePortMapping(port);
                    return port;
                }
            };
            tasks.add(task);
        }
        // Parallelize unmapping all ports.
        try {
            threadPool.invokeAll(tasks, 6, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            log.warn("Interrupted while unmapping ports", e);
        }
    }

    private File locateExecutable() {
        final File file = LanternUtils.osSpecificExecutable("upnpc");
        file.setExecutable(true);
        return file;
    }

    @Override
    public int addUpnpMapping(final PortMappingProtocol protocol, 
            final int localPort,
            final int externalPortRequested, 
            final PortMapListener portMapListener) {
        
        final Runnable upnpRunner = new Runnable() {
            @Override
            public void run() {
                try {
                    
                    final String prot = protocol.name().toUpperCase();
                    final String local = String.valueOf(localPort);
                    final String external = String.valueOf(externalPortRequested);
                    
                    // We don't really care about the outcome of the delete command --
                    // we just want to delete the port in case it's already mapped, as we've
                    // seen UPnP devices ignore subsequent mappings in those cases without
                    // an explicit delete.
                    deletePortMapping(externalPortRequested);
        
                    final ArrayList<String> output = runCommand(exe, "-a", 
                            NetworkUtils.getLocalHost().getHostAddress(), local, external, prot);
                    if (output.isEmpty()) {
                        log.debug("No UPnP output?");
                        portMapListener.onPortMapError();
                        return;
                    }
                    final String last = output.get(output.size()-1);
                    if (last.toLowerCase().contains("failed")) {
                        portMapListener.onPortMapError();
                    } else {
                        mappedPorts.add(externalPortRequested);
                        portMapListener.onPortMap(externalPortRequested);
                    }
                } catch (final IOException e) {
                    log.debug("No IGD perhaps?", e);
                    portMapListener.onPortMapError();
                } catch (final Throwable e) {
                    log.error("Unexpected error?", e);
                    portMapListener.onPortMapError();
                }
            }
        };
        final Thread mapper = new Thread(upnpRunner, "UPnP-Mapping-Thread");
        mapper.setDaemon(true);
        mapper.start();
        
        return 1;
    }

    private void deletePortMapping(final int port) {
        final Runnable upnpRunner = new Runnable() {
            @Override
            public void run() {
                try {
                    runCommand(exe, "-d", String.valueOf(port), "TCP");
                } catch (final IOException e) {
                    log.error("Exception deleting port mapping", e);
                }
            }
        };
        final Thread mapper = new Thread(upnpRunner, "UPnP-Mapping-Thread");
        mapper.setDaemon(true);
        mapper.start();
    }

    private ArrayList<String> runCommand(final File executable, final String... commands) throws IOException {
        final StringBuilder sb = new StringBuilder();
        final ArrayList<String> lines = new ArrayList<String>();
        final LogOutputStream los = new LogOutputStream() {
            @Override
            protected void processLine(final String line, final int level) {
                sb.append(line);
                sb.append("\n");
                lines.add(line);
            }
        };
        final PumpStreamHandler psh = new PumpStreamHandler(los);
        final CommandLine cli = new CommandLine(executable);
        for (final String command : commands) {
            cli.addArgument(command);
        }
        
        final DefaultExecutor executor = new DefaultExecutor();
        executor.setStreamHandler(psh);
        
        try {
            int exitValue = executor.execute(cli);
            log.debug("Got exit value: {}", exitValue);
        } catch (final IOException e) {
            // The DefaultExecutor throws an IOException on error exit codes.
            // In this case, upnpc returns an error code if it can't find any
            // IGD on the network. For us that should just be considered 
            // a port mapping error. If we happen to see some other error, we
            // log it.
            if (lines.size() > 0) {
                final String all = lines.toString();
                if (all.contains("No IGD") || 
                    all.contains("No valid UPNP Internet Gateway Device found")) {
                    log.debug("Got invalid exit value for no IGD", e.getMessage(), 
                            lines.toString(), e);
                }
                else {
                    log.warn("Got invalid exit value: {} with unexpected output:{}", 
                            e.getMessage(), lines.toString(), e);
                } 
                throw e;
            } else {
                log.error("UPNP exception with no output", e);
                throw e;
            }
        }
        log.debug("Received output: {}", sb.toString());
        return lines;
    }

    @Override
    public void removeUpnpMapping(int mappingIndex) {
        
    }

    @Override
    public void shutdown() {
        deleteAllPortMappings();
    }

    @Override
    public void stop() {
        shutdown();
    }

}
