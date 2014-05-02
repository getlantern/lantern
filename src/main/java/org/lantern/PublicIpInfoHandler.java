package org.lantern;

import java.net.InetAddress;

import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.PublicIpEvent;
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
 * waiting for Internet connectivity before looking up an address,
 * performing a geo IP lookup on that address, etc.
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
     * We set the IP address on a proxy connection because we use the proxy
     * itself to determine the IP address. This helps to minimize Lantern's
     * network footprint.
     * 
     * @param pce The proxy connection event.
     * @throws InitException If there was an error fetching the public IP. 
     */
    public void init() throws InitException {
        final InetAddress address = new PublicIpAddress().getPublicIpAddress();
        this.model.getConnectivity().setIp(address != null ? address.getHostAddress() : null);
        if (address == null) {
            throw new InitException("Could not determine public IP");
        }
        handleCensored();
        handleGeoIp(address);
        
        // Post PublicIpEvent so that downstream services like xmpp,
        // FriendsHandler, StatsManager and Loggly can start.
        Events.asyncEventBus().post(new PublicIpEvent());
    }
    
    @Subscribe
    public void onProxyConnectionEvent(
        final ProxyConnectionEvent pce) {
        final ConnectivityStatus stat = pce.getConnectivityStatus();
        switch (stat) {
        case CONNECTED:
            log.debug("Got connected event");
            try {
                init();
            } catch (final InitException e) {
                log.warn("Could not get public IP?", e);
            }
            break;
        case CONNECTING:
            break;
        case DISCONNECTED:
            break;
        default:
            break;
        
        }
    }

    private void handleGeoIp(final InetAddress address) {
        final Location loc = model.getLocation();
        final GeoData geo = geoIpLookupService.getGeoData(address);
        loc.setCountry(geo.getCountrycode());
        loc.setLat(geo.getLatitude());
        loc.setLon(geo.getLongitude());
        Events.sync(SyncPath.LOCATION, loc);
    }

    private void handleCensored() {
        Events.sync(SyncPath.CONNECTIVITY, model.getConnectivity());

        Settings set = model.getSettings();

        if (set.getMode() == null || set.getMode() == Mode.unknown) {
            if (censored.isCensored()) {
                set.setMode(Mode.get);
            }
        } else if (set.getMode() == Mode.give && censored.isCensored()) {
            // want to set the mode to get now so that we don't mistakenly
            // proxy any more than necessary
            set.setMode(Mode.get);
            log.info("Disconnected; setting giveModeForbidden");
            Events.syncModal(model, Modal.giveModeForbidden);
        }
    }
}
