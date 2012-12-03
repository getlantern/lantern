package org.lantern;

import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executors;
import java.io.IOException;
import javax.net.SocketFactory;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.util.HashedWheelTimer;
import org.jboss.netty.util.Timer;

import static org.lantern.TestingUtils.*;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.InMemoryCookieTracker;
import org.lantern.state.Peer;


/** 
 * a MockConnection simulating a "trusted" lantern peer
 *
 */
class MockTrustedConnection extends MockConnection {
 
    LanternKeyStoreManager keyStore;
    CookieTracker cookieTracker;
    int peerPort;
    ServerBootstrap peerServer;
    
    int localPort;    
    LanternHttpProxyServer localProxy;    

    public MockTrustedConnection() throws Exception {
        super();
        
        currentTest = null;
        
        keyStore = createTempKeyStore();
        // certify ourself to ourself...
        keyStore.addBase64Cert(LanternUtils.getMacAddress(), keyStore.getBase64Cert());

        cookieTracker = new InMemoryCookieTracker();

        // start a fake "trusted" peer on a random port
        peerPort = LanternUtils.randomPort();
        FakePeerHandler peerHandler = new FakePeerHandler(this);
        peerServer = startDummyLanternPeer(peerPort, keyStore, peerHandler);
         
        // now rig up a dummy "client" side that connects to our fake trusted peer
        final SocketFactory socketFactory = newTlsSocketFactory(keyStore);
        // a proxy manager that always connects to our fake peer
        final PeerProxyManager proxyManager = new PeerProxyManager() {
            @Override
            public void onPeer(URI peerUri) {}
             
            @Override
            public HttpRequestProcessor processRequest(Channel browserToProxyChannel,
                                                       ChannelHandlerContext ctx,
                                                       MessageEvent me) throws IOException {
                // bypass chit-chat, just connect.
                final Timer timer = new HashedWheelTimer();
                final ServerSocketChannelFactory serverChannelFactory = 
                        new NioServerSocketChannelFactory(
                            Executors.newCachedThreadPool(),
                            Executors.newCachedThreadPool());
                final ClientSocketChannelFactory clientChannelFactory = 
                    new NioClientSocketChannelFactory(
                            Executors.newCachedThreadPool(),
                            Executors.newCachedThreadPool());
                final ChannelGroup channelGroup = 
                    new DefaultChannelGroup("Local-HTTP-Proxy-Server");
                
                /*
                LanternHub.setNettyTimer(timer);
                LanternHub.setServerChannelFactory(serverChannelFactory);
                LanternHub.setClientChannelFactory(clientChannelFactory);
                LanternHub.setChannelGroup(channelGroup);
                */
                Socket sock = socketFactory.createSocket("127.0.0.1", peerPort);
                final ByteTracker byteTracker = new ByteTracker() {
                    
                    @Override
                    public void addUpBytes(long bytes) {}
                    
                    @Override
                    public void addDownBytes(long bytes) {}
                };
                final HttpRequestProcessor proc = 
                    new PeerChannelHttpRequestProcessor(sock, channelGroup, 
                        byteTracker);
                proc.processRequest(browserToProxyChannel, ctx, me);
                return proc;
            }

            @Override
            public void closeAll() {}

            @Override
            public void removePeer(URI uri) {}

            @Override
            public Map<String, Peer> getPeers() {
                return new HashMap<String, Peer>();
            }
        };
        
        /* this proxyprovider will explode if anything but the expected type 
         * of proxy is requested.  When a trusted peer is requested, the 
         * faked proxy manager is given back.
         */
        final ProxyProvider proxyProvider = new ProxyProvider() {
            /*
            @Override
            public PeerProxyManager getTrustedPeerProxyManager() {
                return proxyManager;
            }
            */

            // explosions...
            @Override
            public InetSocketAddress getLaeProxy() {throw new IllegalStateException();}
            //@Override
            //public PeerProxyManager getAnonymousPeerProxyManager() {throw new IllegalStateException();}
            @Override
            public InetSocketAddress getProxy() {throw new IllegalStateException();}
        };
        
        // start a "local" lantern browser proxy on another random port
        localPort = LanternUtils.randomPort();
        //LanternHub.setKeyStoreManager(keyStore);
        localProxy = startMockLanternHttpProxyServer(localPort, proxyProvider, 
            cookieTracker);
    }

    @Override
    public Channel connect() throws Exception {
        ChannelFuture cf = clientBootstrap.connect(new InetSocketAddress("127.0.0.1", localPort));
        cf.await();
        return cf.getChannel();
    }

    @Override 
    public void teardown() throws Exception {}
    
    @Override
    public HttpRequest createBaseRequest(String hostname) {
        // avoid LAE proxies by using a POST request with chunked transfer encoding...
        final HttpRequest req = createPostRequest("http://" + hostname);
        req.setHeader(HttpHeaders.Names.TRANSFER_ENCODING, HttpHeaders.Values.CHUNKED);                
        return req;
    }
    
}