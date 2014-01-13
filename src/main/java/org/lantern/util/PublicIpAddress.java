package org.lantern.util;

import java.io.IOException;
import java.net.InetAddress;

import org.apache.http.Header;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpHead;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.proxy.GiveModeHttpFilters;
import org.littleshoot.util.PublicIp;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class tries to identify the computer's public IP address.
 * 
 * It is a heavily modified version of original implementation from LittleShoot.
 * 
 * This version only makes calls to a proxy in order to obtain the public ip
 * from a response header. No calls are made to 3rd party sites, which is
 * intended to make Lantern less fingerprintable.
 */
public class PublicIpAddress implements PublicIp {

    private static final Logger LOG =
            LoggerFactory.getLogger(PublicIpAddress.class);
    private static final HttpHost TEST_HOST = new HttpHost("www.getlantern.org");

    private static InetAddress publicIp;
    private static long lastLookupTime;

    private final long cacheTime;

    public PublicIpAddress() {
        this(100L);
    }

    public PublicIpAddress(long cacheTime) {
        this.cacheTime = cacheTime;
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
        return proxyLookup();
    }

    private InetAddress proxyLookup() {
        HttpHead request = new HttpHead("/");
        try {
            request.getParams().setParameter(
                    CoreConnectionPNames.CONNECTION_TIMEOUT, 5000);
            HttpResponse response = HttpClientFactory.newProxiedClient()
                    .execute(TEST_HOST, request);
            Header header = response
                    .getFirstHeader(GiveModeHttpFilters.X_LANTERN_OBSERVED_IP);
            if (header == null) {
                return null;
            } else {
                return InetAddress.getByName(header.getValue());
            }
        } catch (IOException ioe) {
            LOG.debug("Unable to do a proxy lookup", ioe);
            return null;
        } finally {
            request.releaseConnection();
        }
    }
    
    
}
