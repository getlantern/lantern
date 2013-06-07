package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;

import org.lastbamboo.common.ice.MappedServerSocket;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class is a server socket for all ICE answerers for a given user agent.
 * Using the single server socket allows us to map the port a single time. On
 * the answerer this makes sense because all the answerer does is forward 
 * data to a server, such as a local HTTP server or a local HTTP proxy server. 
 * We can't do the same on the offerer/client side because we have to map 
 * incoming sockets to the particular ICE session.
 */
public class LanternMappedTcpAnswererServer implements PortMapListener,
    MappedServerSocket {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private int externalPort;

    private final InetSocketAddress serverAddress;
    
    private boolean isPortMapped = false;

    /**
     * Creates a new mapped server for the answerer.
     * 
     * @param natPmpService The NAT PMP mapper.
     * @param upnpService The UPnP mapper.
     * @param serverAddress The address of the server.
     * @throws IOException If there's an error starting the server.
     */
    public LanternMappedTcpAnswererServer(final NatPmpService natPmpService,
        final UpnpService upnpService, final InetSocketAddress serverAddress) {
        if (serverAddress.getPort() == 0) {
            throw new IllegalArgumentException("Cannot map ephemeral port");
        }

        final int port = serverAddress.getPort();
        
        final InetAddress local;
        try {
            local = NetworkUtils.getLocalHost();
        } catch (final UnknownHostException e) {
            log.error("Could not get localhost?", e);
            throw new Error("Could not get localhost address!", e);
        }
        this.serverAddress = new InetSocketAddress(local, port);
        
        // We just set the port to the local port for now, as that's the one
        // we're requesting on the router. If the router does set it to a 
        // different port, we'll get notified and will reset it.
        this.externalPort = port;
        if (!NetworkUtils.isPublicAddress(local)) {
            log.debug("Mapping port: {}", port);
            upnpService.addUpnpMapping(PortMappingProtocol.TCP, port, 
                port, LanternMappedTcpAnswererServer.this);
            natPmpService.addNatPmpMapping(PortMappingProtocol.TCP, port,
                port, LanternMappedTcpAnswererServer.this);
        } else {
            // We consider public addresses to be effectively port mapped.
            this.isPortMapped = true;
        }
    }
    
    @Override
    public InetSocketAddress getHostAddress() {
        return this.serverAddress;
    }

    @Override
    public void onPortMap(final int port) {
        log.debug("Received port mapped: {}", port);
        if (port > 0) {
            this.externalPort = port;
            this.isPortMapped = true;
        }
    }

    @Override
    public void onPortMapError() {
        log.debug("Got port map error.");
        if (!isPortMapped) {
            isPortMapped = false;
        } else {
            log.debug("Port already mapped!");
        }
    }

    @Override
    public boolean isPortMapped() {
        return isPortMapped;
    }

    @Override
    public int getMappedPort() {
        return externalPort;
    }
}
