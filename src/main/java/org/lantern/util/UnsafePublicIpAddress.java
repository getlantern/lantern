package org.lantern.util;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.Collection;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpException;
import org.apache.commons.httpclient.methods.GetMethod;
import org.apache.commons.lang.StringUtils;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.lastbamboo.common.stun.client.StunClient;
import org.lastbamboo.common.stun.client.StunServerRepository;
import org.lastbamboo.common.stun.client.UdpStunClient;
import org.littleshoot.util.PublicIp;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Generalized class that uses various techniques to obtain a public IP address.
 * 
 * TODO: We need to add new methods for this -- Apache lookups and IRC 
 * lookups.
 * 
 * Google: 
 * 
 * Use https://encrypted.google.com/
 * inurl:"server-status" "Apache Server Status for"  
 * 
 * IRC: perl -MIO -e'$x=IO::Socket::INET->new("$ARGV[0]:6667");print $x "USER x x x x\nNICK testip$$\nWHOIS testip$$\n";while(<$x>){if(/PING (\S+)/){print $x "PONG $1\n"}elsif(/^\S+ 378 .* (\S+)/){die$1}}' irc.freenode.org
 *
 * Many thanks to Samy Kamkar!!
 * 
 * PMW: Cargoculted from LittleShoot
 * PMW: Called "Unsafe" because it is quite fingerprintable - it should not be
 *      used in Get mode or in censored regions.
 */
public class UnsafePublicIpAddress implements PublicIp {

    private static final Logger LOG = 
        LoggerFactory.getLogger(PublicIpAddress.class);
    private static InetAddress publicIp;
    private static long lastLookupTime;
    
    private final long cacheTime;

    private static final ExecutorService threadPool = 
        Executors.newCachedThreadPool(new ThreadFactory() {
            
        private int count = 0;
        @Override
        public Thread newThread(final Runnable runner) {
            final Thread thread = new Thread(runner, 
                "Public-IP-Lookup-Thread-"+count);
            thread.setDaemon(true);
            count++;
            return thread;
        }
    });
    
    public UnsafePublicIpAddress() {
        this.cacheTime = 100L;
    }
    
    public UnsafePublicIpAddress(final long cacheTime) {
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
        
        try {
            publicIp = stunLookup();
            return publicIp;
        } catch (final InterruptedException e) {
            LOG.warn("Could not perform STUN lookup", e);
        } catch (final ExecutionException e) {
            LOG.warn("Could not perform STUN lookup", e);
        } catch (final TimeoutException e) {
            LOG.warn("Could not perform STUN lookup", e);
        }

        publicIp = wikiMediaLookup();
        if (publicIp != null) {
            lastLookupTime = System.currentTimeMillis();
            return publicIp;
        }
        publicIp = ifConfigLookup();
        if (publicIp != null) {
            lastLookupTime = System.currentTimeMillis();
            return publicIp;
        }
        return null;
    }

    private InetAddress stunLookup() throws InterruptedException, 
        ExecutionException, TimeoutException {
        final Collection<InetSocketAddress> servers = 
            StunServerRepository.getServers();
        final Collection<Callable<InetAddress>> tasks = 
            new ArrayList<Callable<InetAddress>>(servers.size());
        for (final InetSocketAddress sock : servers) {
            final Callable<InetAddress> task = new Callable<InetAddress>() {
                @Override
                public InetAddress call() throws Exception {
                    final StunClient stun = new UdpStunClient(sock);
                    stun.connect();
                    publicIp = stun.getServerReflexiveAddress().getAddress();
                    lastLookupTime = System.currentTimeMillis();
                    return publicIp;
                }
            };
            tasks.add(task);
        }
        return threadPool.invokeAny(tasks, 12, TimeUnit.SECONDS);
    }

    private static InetAddress ifConfigLookup() {
        final HttpClient client = new HttpClient();
        final GetMethod get = new GetMethod("http://ifconfig.me");
        // The service returns just the IP if we pretend we're curl.
        get.setRequestHeader("User-Agent", 
            "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8r zlib/1.2.3");
        get.setFollowRedirects(true);
        try {
            final int response = client.executeMethod(get);
            if (response < 200 || response > 299) {
                LOG.warn("Got non-200 level response: "+response);
                return null;
            }
            final String body = new String(get.getResponseBody(), "UTF-8");
            LOG.info("Got response body:\n{}", body);
            return InetAddress.getByName(body.trim());
        } catch (final HttpException e) {
            LOG.warn("HTTP error?", e);
        } catch (final IOException e) {
            LOG.warn("Error connecting?", e);
        } catch (final Exception e) {
            LOG.warn("Some other error?", e);
        } finally {
            get.releaseConnection();
        }
        return null;
    }

    private static InetAddress wikiMediaLookup() {
        final HttpClient client = new HttpClient();
        final GetMethod get = 
            new GetMethod("http://geoiplookup.wikimedia.org/");
        get.setFollowRedirects(true);
        try {
            final int response = client.executeMethod(get);
            if (response < 200 || response > 299) {
                LOG.warn("Got non-200 level response: "+response);
                return null;
            }
            final String body = new String(get.getResponseBody(), "UTF-8");
            LOG.info("Got response body:\n{}", body);
            
            final String jsonStr = StringUtils.substringAfter(body, "=").trim();
            final JSONObject json = (JSONObject) JSONValue.parse(jsonStr);
            final String inet = (String) json.get("IP");
            return InetAddress.getByName(inet);
        } catch (final HttpException e) {
            LOG.warn("HTTP error?", e);
        } catch (final IOException e) {
            LOG.warn("Error connecting?", e);
        } catch (final Exception e) {
            LOG.warn("Some other error?", e);
        } finally {
            get.releaseConnection();
        }
        return null;
    }
}
