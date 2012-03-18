package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;
import java.io.IOException;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;

import static org.lantern.TestingUtils.*;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.InMemoryCookieTracker;


/** 
 * a MockConnection simulating a Proxy lantern peer
 *
 */
class MockProxyConnection extends MockConnection {
 
    LanternKeyStoreManager keyStore;
    CookieTracker cookieTracker;
    int peerPort;
    ServerBootstrap peerServer;

    int localPort;
    LanternHttpProxyServer localProxy;

    public MockProxyConnection() throws Exception {
        super();
        
        currentTest = null;
        
        keyStore = createTempKeyStore();
        // certify ourself to ourself...
        keyStore.addBase64Cert(LanternUtils.getMacAddress(), keyStore.getBase64Cert());
        
        cookieTracker = new InMemoryCookieTracker();

        // start a fake proxy peer on a random port
        peerPort = LanternUtils.randomPort();
        FakePeerHandler peerHandler = new FakePeerHandler(this);
        
        peerServer = startDummyLanternPeer(peerPort, keyStore, peerHandler);
         
        /* this proxyprovider will explode if anything but the expected type 
         * of proxy is requested.  When an app engine peer is requested, the 
         * address of our fake app engine server is returned.
         */
        ProxyProvider proxyProvider = new ProxyProvider() {
            @Override
            public InetSocketAddress getProxy() {
                return new InetSocketAddress("localhost", peerPort);
            }

            // this is always asked for, but throwing an IOException 
            // causes us to try the next case (general proxy)
            @Override
            public PeerProxyManager getTrustedPeerProxyManager() {
                return new PeerProxyManager() {
                    @Override
                    public void onPeer(URI peerUri) {}

                    @Override
                    public HttpRequestProcessor processRequest(Channel browserToProxyChannel,
                       ChannelHandlerContext ctx, MessageEvent me) throws IOException {
                           throw new IOException();
                       }

                    @Override
                    public void closeAll() {
                        // TODO Auto-generated method stub
                        
                    }
                    
                };
            }

            // explosions...
            @Override
            public PeerProxyManager getAnonymousPeerProxyManager() {throw new IllegalStateException();}
            @Override
            public InetSocketAddress getLaeProxy() {throw new IllegalStateException();}
        };

         // start a "local" lantern browser proxy on another random port
        localPort = LanternUtils.randomPort();
        localProxy = startMockLanternHttpProxyServer(localPort, proxyProvider, keyStore, cookieTracker);
    }


    @Override
    public Channel connect() throws Exception {
        ChannelFuture cf = clientBootstrap.connect(new InetSocketAddress("127.0.0.1", localPort));
        cf.await();
        return cf.getChannel();
    }
    
    @Override 
    public void teardown() throws Exception {
    }

    @Override
    public HttpRequest createBaseRequest(String hostname) {
        // avoid LAE proxies by using a POST request with chunked transfer encoding.
        // we skip peer proxies by throwing IOException in the trustedPeerProxyManager.
        final HttpRequest req = createPostRequest("http://" + hostname);
        req.setHeader(HttpHeaders.Names.TRANSFER_ENCODING, HttpHeaders.Values.CHUNKED);                
        return req;
    }
}