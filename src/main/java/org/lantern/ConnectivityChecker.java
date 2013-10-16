package org.lantern;

import java.net.InetAddress;
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

    private final Model model;

    private boolean connected = false;

    @Inject
    ConnectivityChecker(final Model model) {
        this.model = model;
    }

    @Override
    public void run() {
        Connectivity connectivity = model.getConnectivity();
        boolean forceCheck = !connectivity.isInternet();
        final InetAddress ip =
                new PublicIpAddress().getPublicIpAddress(forceCheck);
        if (ip == null) {
            LOG.info("No IP -- possibly no internet connection");
            if (connected) {
                connected = false;
                ConnectivityChangedEvent event = new ConnectivityChangedEvent(false, false, null);
                Events.asyncEventBus().post(event);
            }
            return;
        }
        LOG.debug("Connected");
        String oldIp = connectivity.getIp();
        String newIpString = ip.getHostAddress();
        if (newIpString.equals(oldIp)) {
            if (!connected) {
                ConnectivityChangedEvent event = new ConnectivityChangedEvent(true, false, ip);
                Events.asyncEventBus().post(event);
                connected = true;
            }
        } else {
            connected = true;
            ConnectivityChangedEvent event = new ConnectivityChangedEvent(true, true, ip);
            Events.asyncEventBus().post(event);
        }

    }
}
