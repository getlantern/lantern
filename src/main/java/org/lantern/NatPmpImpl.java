package org.lantern;

import java.util.ArrayList;
import java.util.List;

import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import fr.free.miniupnp.libnatpmp.NatPmp;
import fr.free.miniupnp.libnatpmp.NatPmpResponse;

/**
 * NAT-PMP service class that wraps the underlying NAT-PMP implementation
 * from miniupnp's libnatpmp.
 */
@Singleton
public class NatPmpImpl implements NatPmpService {

    static {
        if (System.getProperty("jna.nosys") == null) {
            System.out.println("[*] Set new system property");
            System.setProperty("jna.nosys", "true");
        }
    }

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private NatPmp pmpDevice;

    private final Stats stats;
    private final List<MapRequest> requests =
                new ArrayList<MapRequest>();

    /**
     * Creates a new NAT-PMP instance.
     * 
     * @throws NatPmpException If we could not start NAT-PMP for any reason.
     */
    @Inject
    public NatPmpImpl(final Stats stats) {
        this.stats = stats;
        if (NetworkUtils.isPublicAddress()) {
            // If we're already on the public network, there's no NAT.
            return;
        }
        pmpDevice = new NatPmp();
        
        // We implement the shutdown hook ourselves so we can explicitly 
        // remove all the mappings we've created.
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

            @Override
            public void run() {
                // Remove all the mappings and shutdown.
                log.info("Shutting down NAT-PMP");
                final int num = requests.size();
                for (int i = 0; i < num; i++) {
                    removeNatPmpMapping(i);
                }
                //pmpDevice.shutdown();
                log.info("Finished shutdown for NAT-PMP");
            }
            
        }, "NAT-PMP-Shutdown-Thread"));
    }

    public boolean isNatPmpSupported() {
        //tests to see if NAT-PMP is supported by issuing a getExternalAddress query
        pmpDevice.sendPublicAddressRequest();
        for (int i = 0; i < 5; ++i) {
            NatPmpResponse response = new NatPmpResponse();
            int result = pmpDevice.readNatPmpResponseOrRetry(response);
            if (result == 0) {
                return true;
            }
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                //fallthrough
            }
        }
        return false;
    }

    @Override
    public void removeNatPmpMapping(final int mappingIndex) {
        log.info("Removing mapping...");
        if (NetworkUtils.isPublicAddress()) {
            return;
        }

        final MapRequest request = requests.get(mappingIndex);

        pmpDevice.sendNewPortMappingRequest(request.protocol, request.internalPort, request.externalPort, 0);

    }

    class MapRequest {
        public MapRequest(int protocol, int localPort, int externalPort, int lifeTimeSeconds) {
            this.protocol = protocol;
            this.internalPort = localPort;
            this.externalPort = externalPort;
            this.lifeTimeSeconds = lifeTimeSeconds;
        }

        int protocol;
        int internalPort;
        int externalPort;
        int lifeTimeSeconds;        
    }
    
    @Override
    public int addNatPmpMapping(final PortMappingProtocol prot, 
        final int localPort, final int externalPortRequested,
        final PortMapListener portMapListener) {
        if (NetworkUtils.isPublicAddress()) {
            // If we're already on the public network, there's no NAT.
            return 1;
        }
        if (portMapListener == null) {
            log.error("No listener for addNatPmpMapping");
            throw new NullPointerException("Null listener");
        }
        // This call will block unless we thread it here.
        final Runnable natPmpRunner = new Runnable() {
            @Override
            public void run() {
                // Note we don't pass the requested external port -- with
                // NAT-PMP we just use whatever the router gives us.
                addMapping(prot, localPort, portMapListener);
            }
        };
        final Thread mapper = new Thread(natPmpRunner, "NAT-PMP-Mapping-Thread");
        mapper.setDaemon(true);
        final int index = requests.size();
        mapper.start();
        
        return index;
    }

    protected void addMapping(final PortMappingProtocol prot,
        final int localPort, final PortMapListener portMapListener) {
        log.info("Adding NAT-PMP mapping");
        final int protocol;
        if (prot == PortMappingProtocol.TCP) {
            protocol = 2;
        } else {
            protocol = 1;
        }
        // We just take whatever port the router gives us, ignoring the 
        // requested port.
        final int lifeTimeSeconds = 60 * 60;

        MapRequest map = new MapRequest(protocol, localPort, 0, lifeTimeSeconds);
        
        pmpDevice.sendNewPortMappingRequest(protocol, localPort, -1, lifeTimeSeconds * 1000);
        NatPmpResponse response = new NatPmpResponse();
        int result = -1;
        for (int i = 0; i < 5; ++i) {
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                //fallthrough
            }
            result = pmpDevice.readNatPmpResponseOrRetry(response);
            if (result == 0) {
                break;
            }
        }
        
        if (result == 0) {
            map.externalPort = response.mappedpublicport;
            portMapListener.onPortMap(map.externalPort);
            stats.setNatpmp(true);
        } else {
            portMapListener.onPortMapError();
            stats.setNatpmp(false);
        }
        // We have to add it whether it succeeded or not to keep the indeces 
        // in sync.
        requests.add(map);
    }

    @Override
    public void shutdown() {
        //nothing to do here
    }

}
