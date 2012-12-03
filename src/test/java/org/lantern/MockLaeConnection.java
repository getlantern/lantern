package org.lantern;

import java.net.InetSocketAddress;
import javax.net.ssl.SSLContext;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.handler.codec.http.HttpRequest;

import static org.lantern.TestingUtils.*;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.InMemoryCookieTracker;

/** 
 * a MockConnection simulating an app engine lantern peer
 *
 */
class MockLaeConnection extends MockConnection {
 
    LanternKeyStoreManager keyStore;
    CookieTracker cookieTracker;
    int peerPort;

    ServerBootstrap peerServer;
    FakePeerHandler peerHandler;
    SSLContext oldDefaultContext;

    int localPort;    
    LanternHttpProxyServer localProxy; 

    public MockLaeConnection() throws Exception {
        super(); 
        
        currentTest = null;

        /*
        keyStore = createTempKeyStore();
        LanternHub.setKeyStoreManager(keyStore);
        // certify ourself to ourself...
        keyStore.addBase64Cert(LanternUtils.getMacAddress(), keyStore.getBase64Cert());
        // the app engine handler uses the "default" SSLContext. Since we have 
        // no legit certs for localhost according to this context, we force the
        // default to be something that we do control... whee! we'll put it back later I promise!
        SSLContext hackedDefault = 
            new LanternClientSslContextFactory().getClientContext();
        oldDefaultContext = SSLContext.getDefault();
        SSLContext.setDefault(hackedDefault);
        
        cookieTracker = new InMemoryCookieTracker();

        // start a fake proxy peer on a random port
        peerPort = LanternUtils.randomPort();
        peerHandler = new FakePeerHandler(this);
        peerServer = startDummyLanternPeer(peerPort, keyStore, peerHandler);
        
        // this proxyprovider will explode if anything but the expected type 
        // of proxy is requested.  When an app engine peer is requested, the 
        // address of our fake app engine server is returned.
        ProxyProvider proxyProvider = new ProxyProvider() {
            @Override
            public InetSocketAddress getLaeProxy() {
                return new InetSocketAddress("127.0.0.1", peerPort);
            }

            @Override
            public InetSocketAddress getProxy() {throw new IllegalStateException();}

//            @Override
//            public PeerProxyManager getTrustedPeerProxyManager() {return null;};//throw new IllegalStateException();}
//
//            // explosions...
//            @Override
//            public PeerProxyManager getAnonymousPeerProxyManager() {throw new IllegalStateException();}
        };
        
        // start a "local" lantern browser proxy on another random port
        localPort = LanternUtils.randomPort();
        localProxy = startMockLanternHttpProxyServer(localPort, proxyProvider, 
            cookieTracker);
            */

    }
    
    @Override
    public Channel connect() throws Exception {
        ChannelFuture cf = clientBootstrap.connect(new InetSocketAddress("127.0.0.1", localPort));
        cf.await();
        return cf.getChannel();
    }
    
    @Override 
    public void teardown() throws Exception {
        SSLContext.setDefault(oldDefaultContext);
    }

    @Override
    public HttpRequest createBaseRequest(String hostname) {
        // nothing special, just a get request.  app engine is 
        // chosen first for these.
        final HttpRequest req = createGetRequest("http://" + hostname);
        return req;
    }
    
}