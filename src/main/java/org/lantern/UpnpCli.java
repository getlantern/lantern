package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.LogOutputStream;
import org.apache.commons.exec.PumpStreamHandler;
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

    public UpnpCli() {
        this.exe = locateExecutable();
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
        
        final String prot = protocol.name().toUpperCase();
        final String local = String.valueOf(localPort);
        final String external = String.valueOf(externalPortRequested);
        final Collection<String> delete = runCommand(this.exe, "-d", 
            external, prot);
        
        System.err.println(delete);
        System.err.println();
        try {
            final ArrayList<String> output = runCommand(this.exe, "-a", 
                    NetworkUtils.getLocalHost().getHostAddress(), local, external, prot);
            final String last = output.get(output.size()-1);
            System.out.println("LAST: "+last);
            if (last.toLowerCase().contains("failed")) {
                portMapListener.onPortMapError();
            } else {
                portMapListener.onPortMap(externalPortRequested);
            }
            System.err.println(output);
        } catch (final Throwable e) {
            log.error("Unexpected error?", e);
            portMapListener.onPortMapError();
        }
        return 0;
    }

    private ArrayList<String> runCommand(final File executable, final String... commands) {
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
            System.out.println("EXIT: "+exitValue);
        } catch (IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        System.err.println(sb.toString());
        return lines;
    }

    @Override
    public void removeUpnpMapping(int mappingIndex) {
        // TODO Auto-generated method stub
        
    }

    @Override
    public void shutdown() {
        // TODO Auto-generated method stub
        
    }

    @Override
    public void stop() {
        shutdown();
    }

}
