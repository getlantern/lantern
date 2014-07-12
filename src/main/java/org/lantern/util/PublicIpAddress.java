package org.lantern.util;

import java.net.InetAddress;

import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpResponse;
import org.lantern.LanternUtils;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.util.HostSpoofedHTTPGet.ResponseHandler;
import org.littleshoot.util.PublicIp;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class tries to identify the computer's public IP address.
 * 
 * It is a heavily modified version of original implementation from LittleShoot.
 * 
 * This version makes a host-spoofed call to geo.getiantem.org (pretending to be
 * some other host) in order to look up the public ip.
 */
public class PublicIpAddress implements PublicIp {

    private static final Logger LOG =
            LoggerFactory.getLogger(PublicIpAddress.class);
    private static final String X_REFLECTED_IP = "X-Reflected-Ip";

    private static InetAddress publicIp;
    private static long lastLookupTime;

    private final long cacheTime;
    private final UnsafePublicIpAddress unsafePublicIpAddress;

    public PublicIpAddress() {
        this(100L);
    }

    public PublicIpAddress(long cacheTime) {
        this.cacheTime = cacheTime;
        this.unsafePublicIpAddress = new UnsafePublicIpAddress(cacheTime);
    }

    /**
     * Determines the public IP address of this node.
     * 
     * @return The public IP address for this node.
     */
    @Override
    public InetAddress getPublicIpAddress() {
        return getPublicIpAddress(false);
    }

    /**
     * Determines the public IP address of this node.
     * 
     * @param forceCheck
     *            force a check for the ip address, even if we have one cached
     * 
     * @return The public IP address for this node.
     */
    public InetAddress getPublicIpAddress(boolean forceCheck) {
        final long now = System.currentTimeMillis();
        boolean cachedValueValid =
                now - lastLookupTime < this.cacheTime * 1000 &&
                        (now - lastLookupTime < 2 * 1000 || publicIp != null);
        if (!forceCheck && cachedValueValid) {
            return publicIp;
        }

        LOG.debug("Attempting to find public IP address");
        if (LanternUtils.isFallbackProxy()) {
            LOG.debug("Running as fallback, doing unsafe lookup");
            return unsafePublicIpAddress.getPublicIpAddress(forceCheck);
        } else {
            LOG.debug("Running as client, doing safe lookup");
            return lookupSafe();
        }
    }

    private InetAddress lookupSafe() {
        return GeoIpLookupService
                .httpLookup(null, new ResponseHandler<InetAddress>() {
                    @Override
                    public InetAddress onResponse(HttpResponse response) throws Exception {
                        final int responseCode = response.getStatusLine()
                                .getStatusCode();
                        boolean ok = responseCode >= 200 && responseCode < 300;
                        if (!ok) {
                            LOG.warn(
                                    "Error looking up public ip.  Got status: {}.  Body: {}",
                                    response.getStatusLine(),
                                    IOUtils.toString(response.getEntity()
                                            .getContent()));
                            return InetAddress.getLocalHost();
                        } else {
                            Header header = response
                                    .getFirstHeader(X_REFLECTED_IP);
                            return InetAddress.getByName(header.getValue());
                        }
                    }

                    @Override
                    public InetAddress onException(Exception e) {
                        LOG.warn("Unable to do a safe lookup", e);
                        return null;
                    }
                });
    }
}
