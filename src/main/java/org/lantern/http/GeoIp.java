package org.lantern.http;

import java.net.InetAddress;

import org.lantern.ConnectivityChangedEvent;
import org.lantern.GeoData;
import org.lantern.event.Events;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.state.Location;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;

public class GeoIp {

    private final Model model;
    private final GeoIpLookupService geoIpLookupService;

    private boolean connected = false;

    @Inject
    GeoIp(final Model model, final GeoIpLookupService geoIpLookupService) {
        this.model = model;
        this.geoIpLookupService = geoIpLookupService;
        Events.register(this);
    }

    @Subscribe
    public void onConnectivityChanged(ConnectivityChangedEvent e) {
        if (e.isConnected() && (!connected || e.isIpChanged())) {
            connected = true;
            InetAddress ip = e.getNewIp();
            final Location loc = model.getLocation();
            if (loc.getLat() == 0.0 && loc.getLon() == 0.0) {
                final GeoData geo = geoIpLookupService.getGeoData(ip);
                if (geo.getLatitude() != 0.0 || geo.getLongitude() != 0.0) {
                    loc.setCountry(geo.getCountrycode());
                    loc.setLat(geo.getLatitude());
                    loc.setLon(geo.getLongitude());
                    Events.sync(SyncPath.LOCATION, loc);
                }
            }
        }
    }
}
