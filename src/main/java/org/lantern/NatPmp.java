package org.lantern;

import java.util.ArrayList;
import java.util.List;

import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.hoodcomputing.natpmp.MapRequestMessage;
import com.hoodcomputing.natpmp.MessageType;
import com.hoodcomputing.natpmp.NatPmpDevice;
import com.hoodcomputing.natpmp.NatPmpException;

/**
 * NAT-PMP service class that wraps the underlying NAT-PMP implementation
 * from flszen.
 */
public class NatPmp implements NatPmpService {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final NatPmpDevice pmpDevice;
    
    private final List<MapRequestMessage> requests =
        new ArrayList<MapRequestMessage>();
    
    /**
     * Creates a new NAT-PMP instance.
     * 
     * @throws NatPmpException If we could not start NAT-PMP for any reason.
     */
    public NatPmp() throws NatPmpException {
        pmpDevice = new NatPmpDevice(false);
        
        // We implement the shutdown hook ourselves so we can explicitly 
        // remove all the mappings we've created.
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

            @Override
            public void run() {
                // Remove all the mappings and shutdown.
                final int num = requests.size();
                for (int i = 0; i < num; i++) {
                    removeNatPmpMapping(i);
                }
                pmpDevice.shutdown();
            }
            
        }, "NAT-PMP-Shutdown-Thread"));
    }
    
    @Override
    public void removeNatPmpMapping(final int mappingIndex) {
        final MapRequestMessage request = requests.get(mappingIndex);
        
        final boolean tcp = request.getMessageType() == MessageType.MapTCP;
        
        // Setting the lifetime to zero removes the mapping.
        final MapRequestMessage remove = 
            new MapRequestMessage(tcp, request.getInternalPort(), 
                request.getRequestedExternalPort(), 0, null);
        pmpDevice.enqueueMessage(remove);
        pmpDevice.waitUntilQueueEmpty();
    }
    
    @Override
    public int addNatPmpMapping(final PortMappingProtocol prot, 
        final int localPort, final int externalPortRequested,
        final PortMapListener portMapListener) {
        if (portMapListener == null) {
            log.error("No listener?");
            throw new NullPointerException("Null listener");
        }
        // This call will block unless we thread it here.
        final Runnable upnpRunner = new Runnable() {
            @Override
            public void run() {
                // Note we don't pass the requested external port -- with
                // NAT-PMP we just use whatever the router gives us.
                addMapping(prot, localPort, portMapListener);
            }
        };
        final Thread mapper = new Thread(upnpRunner, "NAT-PMP-Mapping-Thread");
        
        final int index = requests.size();
        mapper.start();
        
        return index;
    }

    protected void addMapping(final PortMappingProtocol prot,
        final int localPort, final PortMapListener portMapListener) {

        final boolean tcp;
        if (prot == PortMappingProtocol.TCP) {
            tcp = true;
        } else {
            tcp = false;
        }
        // We just take whatever port the router gives us, ignoring the 
        // requested port.
        final int lifeTimeSeconds = 60 * 60;
        final MapRequestMessage map = 
            new MapRequestMessage(tcp, localPort, 0, lifeTimeSeconds, null);
        pmpDevice.enqueueMessage(map);
        pmpDevice.waitUntilQueueEmpty();
        try {
            // Auto-boxing can cause a null pointer here, so make sure to
            // use Integer.
            final Integer extPort = map.getExternalPort();
            if (extPort != null) { 
                log.info("Got external port!! "+extPort);
                portMapListener.onPortMap(extPort);
            } else {
                portMapListener.onPortMapError();
            }
        } catch (final NatPmpException e) {
            portMapListener.onPortMapError();
        }
        // We have to add it whether it succeeded or not to keep the indeces 
        // in sync.
        requests.add(map);
    }

}
