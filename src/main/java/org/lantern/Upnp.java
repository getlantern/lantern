package org.lantern;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

import org.lantern.annotation.Keep;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.Sets;

import fr.free.miniupnp.IGDdatas;
import fr.free.miniupnp.MiniupnpcLibrary;
import fr.free.miniupnp.UPNPDev;
import fr.free.miniupnp.UPNPUrls;

public class Upnp implements org.lastbamboo.common.portmapping.UpnpService {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private static final int UPNP_DELAY = 2000;

    private static final MiniupnpcLibrary miniupnpc = MiniupnpcLibrary.INSTANCE;

    private final Stats stats;

    private String publicIp;

    private final Set<UpnpMapping> mappings = new HashSet<UpnpMapping>();

    public Upnp(final Stats stats) {
        this.stats = stats;
    }

    public void removeAllMappings() {
        removeUpnpMappings(Sets.newHashSet(mappings));
    }

    private synchronized void removeUpnpMappings(
        final Collection<UpnpMapping> toRemove) {
        if (toRemove.size() == 0) {
            return;
        }
        log.info("Deleting mappings {}", toRemove);
        UPNPDev devlist = miniupnpc.upnpDiscover(UPNP_DELAY, (String) null,
                (String) null, 0, 0, IntBuffer.allocate(1));
        if (devlist == null) {
            log.debug("No devices?");
            // no devices, so no way to remove mapping
            return;
        }
        
        final UPNPUrls urls = new UPNPUrls();
        final IGDdatas data = new IGDdatas();

        ByteBuffer lanaddr = ByteBuffer.allocate(16);
        int ret = miniupnpc.UPNP_GetValidIGD(devlist, urls, data, lanaddr, 16);
        if (ret == 0) {
            log.debug("No valid IGD?");
            devlist.setAutoRead(false);
            miniupnpc.freeUPNPDevlist(devlist);
            return;
        }
        try {
            logIGDResponse(ret, urls);
            for (UpnpMapping mapping : toRemove) {
                ret = miniupnpc.UPNP_DeletePortMapping(
                        urls.controlURL.getString(0),
                        zeroTerminatedString(data.first.servicetype), ""
                                + mapping.externalPort,
                        mapping.prot.toString(), null);
                if (ret != MiniupnpcLibrary.UPNPCOMMAND_SUCCESS)
                    log.debug("DeletePortMapping() failed with code " + ret);
            }
        } finally {
            miniupnpc.FreeUPNPUrls(urls);
            devlist.setAutoRead(false);
            miniupnpc.freeUPNPDevlist(devlist);
        }
    }

    @Override
    public synchronized void removeUpnpMapping(final int mappingIndex) {
        // We don't actually store mappings by index, so this is a no-op.
    }

    @Override
    public synchronized int addUpnpMapping(final PortMappingProtocol prot,
        final int localPort, final int externalPortRequested,
        final PortMapListener portMapListener) {

        if (NetworkUtils.isPublicAddress()) {
            // Return value is not used.
            return 1;
        }

        // This call will block unless we thread it here.
        final Runnable upnpRunner = new Runnable() {
            @Override
            public void run() {
                addMapping(prot, externalPortRequested, localPort,
                        portMapListener);
            }
        };
        final Thread mapper = new Thread(upnpRunner, "UPnP-Mapping-Thread");
        mapper.setDaemon(true);
        mapper.start();
        
        // Return value is not used.
        return 1;
    }

    @Keep
    static class UpnpMapping {
        public PortMappingProtocol prot;
        public int internalPort;
        public int externalPort;
        @Override
        public String toString() {
            return "UpnpMapping [prot=" + prot + ", internalPort="
                    + internalPort + ", externalPort=" + externalPort + "]";
        }
    }

    protected synchronized void addMapping(final PortMappingProtocol prot,
            final int externalPortRequested, int localPort,
            final PortMapListener portMapListener) {

        ByteBuffer lanaddr = ByteBuffer.allocate(16);
        ByteBuffer intClient = ByteBuffer.allocate(16);
        ByteBuffer intPort = ByteBuffer.allocate(6);
        ByteBuffer desc = ByteBuffer.allocate(80);
        ByteBuffer enabled = ByteBuffer.allocate(4);
        ByteBuffer leaseDuration = ByteBuffer.allocate(16);
        int ret;

        final UPNPUrls urls = new UPNPUrls();
        final IGDdatas data = new IGDdatas();

        UPNPDev devlist = miniupnpc.upnpDiscover(UPNP_DELAY, (String) null,
                (String) null, 0, 0, IntBuffer.allocate(1));
        if (devlist == null) {
            miniupnpc.FreeUPNPUrls(urls);
            portMapListener.onPortMapError();
            return;
        }
        ret = miniupnpc.UPNP_GetValidIGD(devlist, urls, data, lanaddr, 16);
        if (ret == 0) {
            log.debug("No valid UPNP Internet Gateway Device found.");
            portMapListener.onPortMapError();
            miniupnpc.FreeUPNPUrls(urls);
            devlist.setAutoRead(false);
            miniupnpc.freeUPNPDevlist(devlist);
            return;
        }
        try {

            logIGDResponse(ret, urls);

            log.debug("Local LAN ip address : "
                    + zeroTerminatedString(lanaddr.array()));
            ByteBuffer externalAddress = ByteBuffer.allocate(16);
            miniupnpc.UPNP_GetExternalIPAddress(urls.controlURL.getString(0),
                    zeroTerminatedString(data.first.servicetype),
                    externalAddress);
            publicIp = zeroTerminatedString(externalAddress.array());
            log.debug("ExternalIPAddress = " + publicIp);

            ret = miniupnpc.UPNP_AddPortMapping(urls.controlURL.getString(0), // controlURL
                    zeroTerminatedString(data.first.servicetype), // servicetype
                    "" + externalPortRequested, // external Port
                    "" + localPort, // internal Port
                    zeroTerminatedString(lanaddr.array()), // internal client
                    "added via miniupnpc/JAVA !", // description
                    prot.toString(), // protocol UDP or TCP
                    null, // remote host (useless)
                    "0"); // leaseDuration

            if (ret != MiniupnpcLibrary.UPNPCOMMAND_SUCCESS) {
                portMapListener.onPortMapError();
                return;
            }

            // get the local port (but didn't we request one?)
            ret = miniupnpc.UPNP_GetSpecificPortMappingEntry(
                    urls.controlURL.getString(0),
                    zeroTerminatedString(data.first.servicetype), ""
                            + externalPortRequested, prot.toString(),
                    intClient, intPort, desc, enabled, leaseDuration);

            log.debug("InternalIP:Port = "
                    + zeroTerminatedString(intClient.array()) + ":"
                    + zeroTerminatedString(intPort.array()) + " ("
                    + zeroTerminatedString(desc.array()) + ")");

            stats.setUpnp(true);
            
            final UpnpMapping mapping = new UpnpMapping();
            mapping.prot = prot;
            mapping.internalPort = localPort;
            mapping.externalPort = externalPortRequested;
            mappings.add(mapping);
            log.debug("Added mapping. Mappings now: {}", mappings);
        } finally {
            miniupnpc.FreeUPNPUrls(urls);
            devlist.setAutoRead(false);
            miniupnpc.freeUPNPDevlist(devlist);
        }
        portMapListener.onPortMap(externalPortRequested);
    }

    private void logIGDResponse(int i, final UPNPUrls urls) {
        switch (i) {
        case 1:
            log.debug("Found valid IGD : " + urls.controlURL.getString(0));
            break;
        case 2:
            log.debug("Found a (not connected?) IGD : "
                    + urls.controlURL.getString(0));
            log.debug("Trying to continue anyway");
            break;
        case 3:
            log.debug("UPnP device found. Is it an IGD ? : "
                    + urls.controlURL.getString(0));
            log.debug("Trying to continue anyway");
            break;
        default:
            log.debug("Found device (igd ?) : " + urls.controlURL.getString(0));
            log.debug("Trying to continue anyway");

        }
    }

    private String zeroTerminatedString(byte[] array) {
        for (int i = 0; i < array.length; ++i) {
            if (array[i] == 0) {
                return new String(array, 0, i, LanternConstants.UTF8);
            }
        }
        return new String(array, LanternConstants.UTF8);
    }

    @Override
    public void shutdown() {
        log.debug("Shutting down UPnP");
        removeAllMappings();
    }

    public String getPublicIpAddress() {
        return publicIp;
    }
}
