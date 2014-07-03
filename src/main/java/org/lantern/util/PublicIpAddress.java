package org.lantern.util;

import java.io.IOException;
import java.net.InetAddress;

import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.params.ClientPNames;
import org.apache.http.client.params.CookiePolicy;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.LanternUtils;
import org.lantern.S3Config;
import org.lantern.event.Events;
import org.littleshoot.util.PublicIp;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * This class tries to identify the computer's public IP address.
 * 
 * It is a heavily modified version of original implementation from LittleShoot.
 * 
 * This version makes a host-spoofed call to geo.getiantem.org (pretending to be
 * cdnjs.com) in order to look up the public ip.
 */
public class PublicIpAddress implements PublicIp {

    private static final Logger LOG =
            LoggerFactory.getLogger(PublicIpAddress.class);
    private static final String REAL_GEO_HOST = "geo.getiantem.org";
    private static final String X_REFLECTED_IP = "X-Reflected-Ip";

    private static InetAddress publicIp;
    private static long lastLookupTime;

    private final long cacheTime;
    private final UnsafePublicIpAddress unsafePublicIpAddress;

    private static volatile HttpHost s_masqueradeHost =
            new HttpHost(S3Config.DEFAULT_MASQUERADE_HOST, 443, "https");

    static {
        // Subscribe to updates for s_masqueradeHost
        Events.register(new Object() {
            @Subscribe
            public void onNewS3Config(final S3Config config) {
                synchronized (s_masqueradeHost) {
                    s_masqueradeHost = new HttpHost(config.getMasqueradeHost(),
                            443, "https");
                }
            }
        });
    }

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
        HttpGet request = new HttpGet("/lookup");
        request.setHeader("Host", REAL_GEO_HOST);
        try {
            request.getParams().setParameter(
                    CoreConnectionPNames.CONNECTION_TIMEOUT, 60000);
            request.getParams().setParameter(
                    ClientPNames.HANDLE_REDIRECTS, false);
            // Ignore cookies because host spoofing will return cookies that
            // don't match the requested domain
            request.getParams().setParameter(
                    ClientPNames.COOKIE_POLICY, CookiePolicy.IGNORE_COOKIES);
            // Unable to set SO_TIMEOUT because of bug in Java 7
            // See https://github.com/getlantern/lantern/issues/942
            // request.getParams().setParameter(
            // CoreConnectionPNames.SO_TIMEOUT, 60000);
            HttpResponse response = StaticHttpClientFactory.newDirectClient()
                    .execute(s_masqueradeHost, request);
            Header header = response.getFirstHeader(X_REFLECTED_IP);

            final int responseCode = response.getStatusLine().getStatusCode();
            boolean ok = responseCode >= 200 && responseCode < 300;
            if (!ok) {
                LOG.warn(
                        "Error looking up public ip.  Got status: {}.  Body: {}",
                        response.getStatusLine(),
                        IOUtils.toString(response.getEntity().getContent()));
                return InetAddress.getLocalHost();
            } else {
                return InetAddress.getByName(header.getValue());
            }
        } catch (IOException ioe) {
            LOG.warn("Unable to do a safe lookup", ioe);
            return null;
        } finally {
            request.releaseConnection();
        }
    }

}
