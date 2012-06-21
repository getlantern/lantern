package org.lantern;

import java.net.UnknownHostException;

import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.teleal.cling.UpnpService;
import org.teleal.cling.UpnpServiceImpl;
import org.teleal.cling.support.model.PortMapping;
import org.teleal.cling.transport.spi.InitializationException;

public class Upnp implements org.lastbamboo.common.portmapping.UpnpService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public Upnp() {
        final String HACK_STREAM_HANDLER_SYSTEM_PROPERTY = 
            "hackStreamHandlerProperty";
        System.setProperty(HACK_STREAM_HANDLER_SYSTEM_PROPERTY, 
            "alreadyWorkedAroundTheEvilJDK");
    }

    @Override
    public void removeUpnpMapping(final int mappingIndex) {
        // The underlying implementation just removes mappings on shutdown,
        // so we don't need to do this here.
    }
    
    @Override
    public int addUpnpMapping(final PortMappingProtocol prot, 
        final int localPort, final int externalPortRequested,
        final PortMapListener portMapListener) {
        if (NetworkUtils.isPublicAddress()) {
            return 1;
        }
        final String lh;
        try {
            lh = NetworkUtils.getLocalHost().getHostAddress();
        } catch (final UnknownHostException e) {
            log.error("Could not find host?", e);
            return -1;
        }
        
        // This call will block unless we thread it here.
        final Runnable upnpRunner = new Runnable() {
            @Override
            public void run() {
                addMapping(prot, externalPortRequested, 
                    portMapListener, lh);
            }
        };
        final Thread mapper = new Thread(upnpRunner, "UPnP-Mapping-Thread");
        mapper.setDaemon(true);
        mapper.start();
        
        // The mapping index isn't relevant in this case because the underlying
        // UPnP implementation handles removing mappings automatically. We
        // return a positive number to indicate the mapping hasn't failed at
        // this point.
        return 1;
    }

    protected void addMapping(final PortMappingProtocol prot, 
        final int externalPortRequested, 
        final PortMapListener portMapListener, final String lh) {

        final PortMapping desiredMapping = new PortMapping(
            externalPortRequested,
            lh,
            prot == PortMappingProtocol.TCP ? PortMapping.Protocol.TCP : PortMapping.Protocol.UDP,
            "Lantern Port Mapping"
        );

        final UpnpService upnpService;
        try {
            upnpService = new UpnpServiceImpl(
                new UpnpPortMappingListener(portMapListener, desiredMapping)
            );
        } catch (final InitializationException e) {
            final String msg = e.getMessage();
            if (msg.contains("no Inet4Address associated")) {
                log.info("Could not map -- no internet access?", e);
            } else {
                log.error("Could not map port", e);
            }
            return;
        }

        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                upnpService.shutdown();
            }
        });
        
        upnpService.getControlPoint().search();
    }

}
