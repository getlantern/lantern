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
 * NAT-PMP service class that wraps the underlying NAT-PMP implementation from
 * miniupnp's libnatpmp.
 */
@Singleton
public class NatPmpImpl implements NatPmpService {

    static {
        if (System.getProperty("jna.nosys") == null) {
            System.setProperty("jna.nosys", "true");
        }
    }

    private final Logger log = LoggerFactory.getLogger(getClass());

    private NatPmp pmpDevice = null;

    private final ClientStats stats;
    private final List<MapRequest> requests = new ArrayList<MapRequest>();

    /**
     * Creates a new NAT-PMP instance.
     * 
     * @throws NatPmpException
     *             If we could not start NAT-PMP for any reason.
     */
    @Inject
    public NatPmpImpl(final ClientStats stats) {
        this.stats = stats;
        pmpDevice = new NatPmp();
        log.debug("NAT-PMP device = {}", pmpDevice);
    }

    public boolean isNatPmpSupported() {
        if (NetworkUtils.isPublicAddress()) {
            // If we're already on the public network, there's no NAT.
            return false;
        }
        // tests to see if NAT-PMP is supported by issuing a getExternalAddress
        // query
        log.debug("NAT-PMP device = {}", pmpDevice);
        if (pmpDevice == null) {
            return false;
        }
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
                // fallthrough
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

        pmpDevice.sendNewPortMappingRequest(request.protocol,
                request.internalPort, request.externalPort, 0);

    }

    class MapRequest {
        public MapRequest(int protocol, int localPort, int externalPort,
                int lifeTimeSeconds) {
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

        if (pmpDevice == null) {
            return;
        }

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

        pmpDevice.sendNewPortMappingRequest(protocol, localPort, -1,
                lifeTimeSeconds * 1000);
        final NatPmpResponse response = new NatPmpResponse();
        int result = -1;
        for (int i = 0; i < 80; ++i) {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                // fallthrough
            }
            result = pmpDevice.readNatPmpResponseOrRetry(response);
            if (result == 0) {
                break;
            }
        }

        if (result == 0) {
            log.debug("Received successful NAT-PMP response mapping local " +
                    "port {} to remote port {}", 
                    localPort, response.mappedpublicport);
            map.externalPort = response.mappedpublicport;
            portMapListener.onPortMap(map.externalPort);
            stats.setNatpmp(true);
        } else {
            log.debug("Did not receive port mapping response for local {}", 
                    localPort);
            portMapListener.onPortMapError();
            stats.setNatpmp(false);
        }
        // We have to add it whether it succeeded or not to keep the indices
        // in sync.
        requests.add(map);
    }

    @Override
    public void shutdown() {
        // Remove all the mappings and shutdown.
        log.info("Shutting down NAT-PMP");
        final int num = requests.size();
        for (int i = 0; i < num; i++) {
            removeNatPmpMapping(i);
        }
        // pmpDevice.shutdown();
        log.info("Finished shutdown for NAT-PMP");
    }

}
