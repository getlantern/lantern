package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.TimerTask;

import org.lantern.event.Events;
import org.lantern.state.Connectivity;
import org.lantern.state.Model;
import org.littleshoot.proxy.impl.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;

public class ConnectivityChecker extends TimerTask {
    private static Logger LOG = LoggerFactory
            .getLogger(ConnectivityChecker.class);
    private static final String[] TEST_SITES = new String[] {
            "mail.yahoo.com",
            "www.microsoft.com",
            "blogfa.com",
            "www.baidu.com"
    };
    private static final int TEST_SOCKET_TIMEOUT_MILLIS = 30000;

    private final Model model;

    @Inject
    ConnectivityChecker(final Model model) {
        this.model = model;
    }

    @Override
    public void run() {
        final boolean wasConnected = 
                Boolean.TRUE.equals(model.getConnectivity().isInternet());
        final InetAddress ip = localIpAddressIfConnected();
        if (ip != null) {
            if (!wasConnected) {
                LOG.info("Became connected");
                notifyConnected(ip);
            }
            this.model.getConnectivity().setInternet(Boolean.TRUE);
        } else {
            if (wasConnected) {
                LOG.info("Became disconnected");
                notifyDisconnected();
            }
            this.model.getConnectivity().setInternet(Boolean.FALSE);
        }
    }

    private InetAddress localIpAddressIfConnected() {
        // Check if the Internet is reachable
        boolean internetIsReachable = areAnyTestSitesReachable();

        if (internetIsReachable) {
            LOG.debug("Internet is reachable...");
            //boolean forceCheck = !wasConnected;
            //return new PublicIpAddress().getPublicIpAddress(forceCheck);
            try {
                return NetworkUtils.getLocalHost();
            } catch (UnknownHostException e) {
                LOG.error("Could not get local host?", e);
            }
        } 
        
        LOG.info("None of the test sites were reachable -- no internet connection");
        return null;
    }

    private void notifyConnected(InetAddress ip) {
        Connectivity connectivity = model.getConnectivity();
        String oldIp = connectivity.getIp();
        String newIpString = ip.getHostAddress();
        
        connectivity.setIp(newIpString);
        if (newIpString.equals(oldIp)) {
            if (!model.getConnectivity().isInternet()) {
                LOG.info("Became connected with same IP address");
                ConnectivityChangedEvent event = new ConnectivityChangedEvent(
                        true, false, ip);
                Events.asyncEventBus().post(event);
            }
        } else {
            LOG.info("IP address changed");
            ConnectivityChangedEvent event = new ConnectivityChangedEvent(true,
                    true, ip);
            Events.asyncEventBus().post(event);
        }
        
    }

    private void notifyDisconnected() {
        ConnectivityChangedEvent event = new ConnectivityChangedEvent(
                false, false, null);
        Events.asyncEventBus().post(event);
    }

    private static boolean areAnyTestSitesReachable() {
        for (String site : TEST_SITES) {
            if (isReachable(site)) {
                return true;
            }
        }
        return false;
    }

    private static boolean isReachable(String site) {
        Socket socket = null;
        try {
            socket = new Socket();
            LOG.debug("Testing site: {}", site);
            socket.connect(new InetSocketAddress(site, 80),
                    TEST_SOCKET_TIMEOUT_MILLIS);
            return true;
        } catch (Exception e) {
            LOG.debug("Could not connect", e);
            // Ignore
            return false;
        } finally {
            if (socket != null) {
                try {
                    socket.close();
                } catch (Exception e) {
                    LOG.debug("Unable to close connectivity test socket: {}",
                            e.getMessage(), e);
                }
            }
        }
    }
}
