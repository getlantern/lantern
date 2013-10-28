package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.TimerTask;

import org.lantern.event.Events;
import org.lantern.state.Connectivity;
import org.lantern.state.Model;
import org.lantern.util.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;

public class ConnectivityChecker extends TimerTask {
    private static Logger LOG = LoggerFactory
            .getLogger(ConnectivityChecker.class);
    private static final String[] TEST_SITES = new String[] {
            "www.google.com",
            "blogfa.com",
            "www.baidu.com"
    };
    private static final int TEST_SOCKET_TIMEOUT_MILLIS = 30000;

    private final Model model;

    private boolean wasConnected;

    @Inject
    ConnectivityChecker(final Model model) {
        this.model = model;
    }

    @Override
    public void run() {
        wasConnected = model.getConnectivity().isInternet();
        InetAddress ip = determineCurrentIpAddress();
        if (ip != null) {
            notifyConnected(ip);
        } else {
            if (wasConnected) {
                LOG.info("Became disconnected");
                notifyDisconnected();
            }
        }
    }

    private InetAddress determineCurrentIpAddress() {
        // Check if the Internet is reachable
        boolean internetIsReachable = areAnyTestSitesReachable();

        InetAddress ip = null;
        if (internetIsReachable) {
            LOG.debug("Internet is reachable, determine our IP address");
            boolean forceCheck = !wasConnected;
            ip = new PublicIpAddress().getPublicIpAddress(forceCheck);
        }

        if (!internetIsReachable) {
            LOG.info("None of the test sites were reachable -- possibly no internet connection");
            return null;
        }
        if (ip == null) {
            LOG.info("No IP -- possibly no internet connection");
            return null;
        }

        return ip;
    }

    private void notifyConnected(InetAddress ip) {
        Connectivity connectivity = model.getConnectivity();
        String oldIp = connectivity.getIp();
        String newIpString = ip.getHostAddress();
        if (newIpString.equals(oldIp)) {
            if (!wasConnected) {
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
            socket.connect(new InetSocketAddress(site, 80),
                    TEST_SOCKET_TIMEOUT_MILLIS);
            return true;
        } catch (Exception e) {
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
