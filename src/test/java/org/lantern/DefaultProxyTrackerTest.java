package org.lantern;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.SocketTimeoutException;
import java.net.URI;

import org.junit.Test;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.NetworkTracker;
import org.lantern.proxy.DefaultProxyTracker;
import org.lantern.proxy.ProxyHolder;
import org.lantern.proxy.ProxyInfo;
import org.lantern.state.Model;
import org.lantern.stubs.PeerFactoryStub;
import org.littleshoot.util.FiveTuple;

import com.google.common.eventbus.Subscribe;

public class DefaultProxyTrackerTest {
    
    @Subscribe
    public void onProxyConnectionEvent(final ProxyConnectionEvent pce) {
        synchronized (this) {
            this.notifyAll();
        }
    }
    
    @Test
    public void testDefaultProxyTracker() throws Exception {
        
        Events.register(this);
        final Censored censored = new DefaultCensored();
        final CountryService countryService = new CountryService(censored);
        Model model = new Model(countryService);

        //assume that we are connected to the Internet
        model.getConnectivity().setInternet(true);

        final GeoIpLookupService geoIpLookupService = new GeoIpLookupService();
        PeerFactory peerFactory = new PeerFactoryStub();
        LanternTrustStore lanternTrustStore = mock(LanternTrustStore.class);
        DefaultProxyTracker tracker = new DefaultProxyTracker(model,
                peerFactory, lanternTrustStore, new NetworkTracker<String, URI, ReceivedKScopeAd>());
        
        tracker.init();
        tracker.start();

        //proxy queue initially empty
        ProxyHolder proxy = tracker.firstConnectedTcpProxy();
        assertNotNull(proxy);
        assertTrue("There should always be a flashlight proxy available", proxy.getJid().toString().contains("flashlight"));

        final int port1 = 55077;
        final int port2 = 55078;
        
        
        Miniproxy miniproxy1 = new Miniproxy(port1);
        new Thread(miniproxy1).start();
        LanternUtils.waitForServer(miniproxy1.port, 4000);

        Miniproxy miniproxy2 = new Miniproxy(port2);
        new Thread(miniproxy2).start();
        LanternUtils.waitForServer(miniproxy2.port, 4000);
        

        InetAddress localhost = org.littleshoot.proxy.impl.NetworkUtils.getLocalHost();
        final ProxyInfo info = new ProxyInfo(new URI("proxy1@example.com"), localhost.getHostAddress(), port1);
        assertNotNull(info.fiveTuple());
        
        tracker.addProxy(info);
        
        // Leave time for proxy connectivity check to happen
        Thread.sleep(1000);
        proxy = waitForProxy(tracker);
        
        assertNotNull(proxy);
        
        assertEquals(port1, getProxyPort(proxy));

        //now let's force the proxy to fail.
        //miniproxy1.pause();

        proxy = tracker.firstConnectedTcpProxy();
        // first, we need to clear out the old proxy from the list, by having it
        // fail.
        
        tracker.onCouldNotConnect(proxy);
        //now wait for the miniproxy to stop accepting.
        Thread.sleep(10);

        proxy = tracker.firstConnectedTcpProxy();
        assertNotNull(proxy);
        assertTrue("The remaining proxy should be a flashlight", proxy.getJid().toString().contains("flashlight"));

        // now bring miniproxy1 back up
        // miniproxy1.unpause();
        Thread.sleep(10);

        //let's turn off internet, which will restore the dead proxy
        model.getConnectivity().setInternet(false);
        //Events.eventBus().post(new ConnectivityChangedEvent(true));
        tracker.init();
        Thread.sleep(10);

        proxy = tracker.firstConnectedTcpProxy();
        assertNotNull("Recently deceased proxy not restored", proxy);
        Thread.sleep(10);
        model.getConnectivity().setInternet(true);
        //Events.eventBus().post(new ConnectivityChangedEvent(true));
        tracker.init();
        
        tracker.firstConnectedTcpProxy();
        Thread.sleep(10);

        // with multiple proxies, we get a different proxy for each getProxy()
        // call
        tracker.addProxy(new ProxyInfo(new URI("proxy2@example.com"), localhost.getHostAddress(), port2));
        /*
        Thread.sleep(50);
        ProxyHolder proxy1 = waitForProxy(tracker);
        System.err.println(proxy1);
        // Simulate a successful connection to proxy1 to bump its socket count 
        proxy1.connectionSucceeded();
        ProxyHolder proxy2 = waitForProxy(tracker);
        System.err.println(proxy2);
        assertNotNull(proxy1);
        assertNotNull(proxy2);
        assertTrue(proxy1 != proxy2);
        int port1 = getProxyPort(proxy1);
        int port2 = getProxyPort(proxy2);
        assertTrue((port1 == 55021 && port2 == 55022) || (port1 == 55022 && port2 == 55021));
    */
    }

    private ProxyHolder waitForProxy(DefaultProxyTracker tracker) 
        throws Exception {
        
        int tries = 0;
        while (tries < 1000) {
            final ProxyHolder proxy = tracker.firstConnectedTcpProxy();
            if (proxy != null) {
                return proxy;
            }
            Thread.sleep(10);
            tries ++;
            //return tracker.firstConnectedTcpProxy();
        }
        return null;
    }

    private int getProxyPort(ProxyHolder proxy) {
        final FiveTuple ft = proxy.getFiveTuple();
        final InetSocketAddress remote = ft.getRemote();
        return remote.getPort();
    }

    static class Miniproxy implements Runnable {

        public volatile boolean done = false;
        private final int port;
        private boolean paused;

        public Miniproxy(int port) {
            this.port = port;
        }

        public void unpause() {
            paused = false;
        }

        public void pause() {
            paused = true;
        }

        @Override
        public void run() {
            ServerSocket sock;
            try {
                //InetAddress lh = org.littleshoot.proxy.impl.NetworkUtils.getLocalHost();
                sock = new ServerSocket(port);
                sock.setSoTimeout(1);
                while (!done) {
                    try {
                        if (!paused) {
                            sock.accept();
                        }
                    } catch (SocketTimeoutException e) {
                        // no connections; just loop
                    }

                    try {
                        Thread.sleep(0);
                    } catch (InterruptedException e) {
                    }
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

    }
}
