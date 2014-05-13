package org.lantern;

import java.net.ConnectException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.TimerTask;

import org.lantern.event.Events;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;

public class ConnectivityChecker extends TimerTask {
    private static Logger LOG = LoggerFactory
            .getLogger(ConnectivityChecker.class);
    private static final List<String> TEST_SITES = Arrays.asList(
            "mail.yahoo.com",
            "www.microsoft.com",
            "blogfa.com",
            "www.baidu.com"
    );
    private static final int TEST_SOCKET_TIMEOUT_MILLIS = 30000;

    private final Model model;

    @Inject
    ConnectivityChecker(final Model model) {
        this.model = model;
    }
    
    public void connect() throws ConnectException {
        if (!checkConnectivity()) {
            throw new ConnectException("Could not connect");
        }
    }

    @Override
    public void run() {
        checkConnectivity();
    }
    
    public boolean checkConnectivity() {
        final boolean wasConnected = 
                Boolean.TRUE.equals(model.getConnectivity().isInternet());
        final boolean connected = areAnyTestSitesReachable();
        this.model.getConnectivity().setInternet(connected);
        boolean becameConnected = connected && !wasConnected;
        boolean becameDisconnected = !connected && wasConnected;
        if (becameConnected) {
            LOG.info("Became connected");
            notifyConnected();
        } else if (becameDisconnected) {
            LOG.info("Became disconnected");
            this.model.getConnectivity().setIp(null);
            notifyDisconnected();
        }
        Events.sync(SyncPath.CONNECTIVITY, model.getConnectivity());
        return connected;
    }

    private void notifyConnected() {
        LOG.info("Became connected...");
        notifyListeners(true);
    }

    private void notifyDisconnected() {
        LOG.info("Became disconnected...");
        notifyListeners(false);
    }
    
    private void notifyListeners(final boolean connected) {
        ConnectivityChangedEvent event = new ConnectivityChangedEvent(connected);
        Events.asyncEventBus().post(event);
    }

    private static boolean areAnyTestSitesReachable() {
        Collections.shuffle(TEST_SITES);
        for (String site : TEST_SITES) {
            if (isReachable(site)) {
                return true;
            }
        }
        LOG.info("None of the test sites were reachable -- no internet connection");
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
            LOG.debug("Could not connect to "+site, e);
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
