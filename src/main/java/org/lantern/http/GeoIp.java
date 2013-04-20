package org.lantern.http;

import java.net.InetAddress;

import org.lantern.ConnectivityChangedEvent;
import org.lantern.GeoData;
import org.lantern.event.Events;
import org.lantern.state.Location;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.SyncPath;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;

public class GeoIp {

    private final Model model;
    private final ModelUtils modelUtils;

    @Inject
    GeoIp(final Model model, final ModelUtils modelUtils) {
        this.model = model;
        this.modelUtils = modelUtils;
        Events.register(this);
    }

    @Subscribe
    public void onConnectivityChanged(ConnectivityChangedEvent e) {
        if (e.isConnected() && e.isIpChanged()) {
            InetAddress ip = e.getNewIp();
            String newIpString = ip.getHostAddress();
            final Location loc = model.getLocation();
            if (loc.getLat() == 0.0 && loc.getLon() == 0.0) {
                final GeoData geo = modelUtils.getGeoData(newIpString);
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
