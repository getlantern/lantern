package org.lantern.simple;

import io.netty.handler.codec.http.HttpRequest;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.Map;

import org.lantern.geoip.GeoIpLookupService;
import org.lantern.proxy.GiveModeActivityTracker;
import org.lantern.state.InstanceStats;
import org.lantern.util.HostExtractor;
import org.littleshoot.proxy.FlowContext;

public class FallbackActivityTracker extends GiveModeActivityTracker {
    private volatile Map<String, Map<String, Long>> hostRequestsByCountry =
            new HashMap<String, Map<String, Long>>();

    public FallbackActivityTracker(InstanceStats stats,
            GeoIpLookupService lookupService) {
        super(stats, lookupService, null);
    }

    @Override
    public void requestReceivedFromClient(FlowContext flowContext,
            HttpRequest httpRequest) {
        super.requestReceivedFromClient(flowContext, httpRequest);
        String host = HostExtractor.extractHost(httpRequest.getUri());
        if (host != null) {
            InetAddress peerAddress = flowContext
                    .getClientAddress().getAddress();
            String country = lookupService.getGeoData(peerAddress)
                    .getCountry().getIsoCode();
            synchronized (this) {
                Map<String, Long> hostRequestsForCountry =
                        hostRequestsByCountry.get(country);
                if (hostRequestsForCountry == null) {
                    hostRequestsForCountry = new HashMap<String, Long>();
                    hostRequestsByCountry.put(country, hostRequestsForCountry);
                }
                Long hostRequests = hostRequestsForCountry.get(host);
                if (hostRequests == null) {
                    hostRequests = 1l;
                } else {
                    hostRequests += 1;
                }
                hostRequestsForCountry.put(host, hostRequests);
            }
        }
    }

    synchronized public Map<String, Map<String, Long>> pollHostRequestsByCountry() {
        Map<String, Map<String, Long>> result = hostRequestsByCountry;
        hostRequestsByCountry = new HashMap<String, Map<String, Long>>();
        return result;
    }
}
