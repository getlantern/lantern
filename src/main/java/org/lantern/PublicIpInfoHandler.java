package org.lantern;

import java.net.ConnectException;
import java.net.InetAddress;

import org.lantern.event.Events;
import org.lantern.event.PublicIpEvent;
import org.lantern.geoip.GeoData;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.state.Location;
import org.lantern.state.Modal;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.Settings;
import org.lantern.state.SyncPath;
import org.lantern.util.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class handles everything associated with a public IP address, including
 * waiting for Internet connectivity before looking up an address, performing a
 * geo IP lookup on that address, etc.
 */
@Singleton
public class PublicIpInfoHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Model model;
    private final Censored censored;
    private final GeoIpLookupService geoIpLookupService;

    @Inject
    public PublicIpInfoHandler(final Model model, final Censored censored,
            final GeoIpLookupService geoIpLookupService) {
        this.model = model;
        this.censored = censored;
        this.geoIpLookupService = geoIpLookupService;
        Events.register(this);
    }

    /**
     * We determine the public ip anytime that we've achieved internet
     * connectivity.
     * 
     * @param event
     */
    @Subscribe
    public void onConnectivityChanged(final ConnectivityChangedEvent event) {
        log.debug("Got ConnectivityChangedEvent");
        if (event.isConnected()) {
            log.debug("Determining public ip");
            try {
                determinePublicIp();
            } catch (final ConnectException e) {
                log.warn("Could not get public IP?", e);
            }
        } else {
            log.debug("Not connected to the internet, not determining public ip");
        }
    }

    /**
     * Determines the public ip address using PublicIpAddress.
     * 
     * @throws ConnectException
     *             If there was an error fetching the public IP.
     */
    private void determinePublicIp() throws ConnectException {
        InetAddress address = null;
        for (int i = 0; i < 10; i++) {
            // Try a few times to get the public ip address
            // We do this because for some reason, if we've just restored
            // connectivity and gotten a connected event, connecting to the
            // geo service to do an IP lookup sometimes fails.
            try {
                // Back off a little on each try
                Thread.sleep(i * i * 100);
            } catch (InterruptedException ie) {
                // ignore
            }
            address = new PublicIpAddress().getPublicIpAddress();
            if (address != null) {
                break;
            }
        }

        this.model.getConnectivity().setIp(
                address != null ? address.getHostAddress() : null);
        if (address == null) {
            throw new ConnectException("Could not determine public IP");
        }

        handleCensored(address);
        handleGeoIp(address);

        // Post PublicIpEvent so that downstream services like xmpp,
        // FriendsHandler, StatsManager and Loggly can start.
        Events.asyncEventBus().post(new PublicIpEvent());
    }

    private void handleGeoIp(final InetAddress address) {
        final Location loc = model.getLocation();
        final GeoData geo = geoIpLookupService.getGeoData(address);
        loc.setCountry(geo.getCountry().getIsoCode());
        loc.setLat(geo.getLocation().getLatitude());
        loc.setLon(geo.getLocation().getLongitude());
        loc.setResolved(true);
        Events.sync(SyncPath.LOCATION, loc);
    }

    private void handleCensored(final InetAddress address) {
        // The UI actually determines whether or not it shows a spinner using
        // connectivity.
        Events.sync(SyncPath.CONNECTIVITY, model.getConnectivity());
        final Settings set = model.getSettings();

        if (set.getMode() == null || set.getMode() == Mode.unknown) {
            if (censored.isCensored(address)) {
                set.setMode(Mode.get);
                Events.sync(SyncPath.SETTINGS, set);
            }
        } else if (set.getMode() == Mode.give && censored.isCensored(address)) {
            // want to set the mode to get now so that we don't mistakenly
            // proxy any more than necessary
            set.setMode(Mode.get);
            log.info("Disconnected; setting giveModeForbidden");
            Events.syncModal(model, Modal.giveModeForbidden);
            Events.sync(SyncPath.SETTINGS, set);
        }
    }
}
