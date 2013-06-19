package org.lantern;

import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Properties;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import javax.net.ssl.SSLEngine;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBufferFactory;
import org.jboss.netty.channel.AbstractChannel;
import org.jboss.netty.channel.AbstractChannelSink;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineException;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelSink;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.DefaultChannelConfig;
import org.jboss.netty.channel.DefaultChannelFuture;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.CookieDecoder;
import org.jboss.netty.handler.codec.http.DefaultHttpRequest;
import org.jboss.netty.handler.codec.http.DefaultHttpResponse;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.jboss.netty.handler.ssl.SslHandler;
import org.jboss.netty.util.HashedWheelTimer;
import org.jboss.netty.util.Timer;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.RandomRoutingTable;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.StoredCookie;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.kscope.DefaultKscopeAdHandler;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.state.DefaultModelUtils;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Peer.Type;
import org.lantern.state.Settings;
import org.lantern.stubs.ProxyTrackerStub;
import org.lantern.ui.NotificationManager;
import org.lantern.util.HttpClientFactory;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.ProxyCacheManager;
import org.littleshoot.proxy.ProxyHttpResponseEncoder;
import org.littleshoot.proxy.SslContextFactory;

public class TestingUtils {

    private static final File privatePropsFile;

    private static final Properties privateProps = new Properties();
    
    static {
        if (LanternClientConstants.TEST_PROPS.isFile()) {
            privatePropsFile = LanternClientConstants.TEST_PROPS;
        } else {
            privatePropsFile = LanternClientConstants.TEST_PROPS2;
        }
        if (privatePropsFile.isFile()) {
            InputStream is = null;
            try {
                is = new FileInputStream(privatePropsFile);
                privateProps.load(is);
            } catch (final IOException e) {
                System.err.println("NO PRIVATE PROPS FILE AT "+
                    privatePropsFile.getAbsolutePath());
                e.printStackTrace();
            } finally {
                IOUtils.closeQuietly(is);
            }
            
            if (StringUtils.isBlank(getRefreshToken()) ||
                StringUtils.isBlank(getAccessToken())) {
                System.err.println("NO REFRESH OR ACCESS TOKENS!!");
                throw new Error("Tokens not in "+privatePropsFile);
            }
        } else {
            throw new Error("Could not load!!");
        }
    }

    public static Model newModel() {
        return new Model(newCountryService());
    }
    
    public static CountryService newCountryService() {
        final Censored censored = new DefaultCensored();
        return new CountryService(censored);
    }

    public static XmppHandler newXmppHandler() {
        final Censored censored = new DefaultCensored();
        final Model mod = new Model(new CountryService(censored));
        final Settings set = mod.getSettings();
        set.setAccessToken(getAccessToken());
        set.setRefreshToken(getRefreshToken());
        set.setUseGoogleOAuth2(true);
        return newXmppHandler(censored, mod);
    }
    
    

    public static ProxyTracker newProxyTracker() {
        return new ProxyTrackerStub() {
            @Override
            public ProxyHolder getProxy() {
                final InetSocketAddress tuple = 
                    new InetSocketAddress("54.251.192.164", 11225);
                final URI uri;
                try {
                    uri = new URI("fallback@getlantern.org");
                } catch (URISyntaxException e) {
                    return null;
                }
                return new ProxyHolder("", uri, tuple, null, Type.cloud);
            }
        };
    }
    
    public static XmppHandler newXmppHandler(final Censored censored, final Model model) {
        
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        //final String testId = "test@gmail.com/somejidresource";
        //trustStore.addBase64Cert(new URI(testId), ksm.getBase64Cert(testId));
        
        final LanternSocketsUtil socketsUtil = 
            new LanternSocketsUtil(null, trustStore);
        
        // Using a mock here creates an OOME and/or stack overflow when trying
        // to convert to JSON. Use a stub instead.
        final ClientStats stats = new StatsStub();
        final java.util.Timer updateTimer = new java.util.Timer();

        //final ProxyTracker proxyTracker = newProxyTracker();
        

        
        final ModelUtils modelUtils = new DefaultModelUtils(model);
        final RandomRoutingTable routingTable = new BasicRandomRoutingTable();
        final Roster roster = new Roster(routingTable, model, censored);
        
        final GeoIpLookupService geoIpLookupService = new GeoIpLookupService();
        
        final PeerFactory peerFactory = 
            new DefaultPeerFactory(geoIpLookupService, model, roster);
        final Timer timer = new HashedWheelTimer();
        final ProxyTracker proxyTracker = 
            new DefaultProxyTracker(model, peerFactory, timer, null);
        final KscopeAdHandler kscopeAdHandler = 
            new DefaultKscopeAdHandler(proxyTracker, trustStore, routingTable, 
                null, model);
        final NatPmpService natPmpService = new NatPmpService() {
            @Override
            public void shutdown() {}
            @Override
            public void removeNatPmpMapping(int mappingIndex) {}
            @Override
            public int addNatPmpMapping(PortMappingProtocol protocol, int localPort,
                    int externalPortRequested, PortMapListener portMapListener) {
                return 0;
            }
        };
        final UpnpService upnpService = new UpnpService() {
            @Override
            public void shutdown() {}
            @Override
            public void removeUpnpMapping(int mappingIndex) {}
            @Override
            public int addUpnpMapping(PortMappingProtocol protocol, int localPort,
                    int externalPortRequested, PortMapListener portMapListener) {
                return 0;
            }
        };
        
        final ProxySocketFactory proxySocketFactory =
                new ProxySocketFactory(socketsUtil, proxyTracker);
        final LanternXmppUtil xmppUtil = new LanternXmppUtil(socketsUtil, 
                proxySocketFactory);

        NotificationManager notificationManager = mock(NotificationManager.class);

        final XmppHandler xmppHandler = new DefaultXmppHandler(model,
            updateTimer, stats, ksm, socketsUtil, xmppUtil, modelUtils,
            roster, proxyTracker, kscopeAdHandler, natPmpService, upnpService,
            notificationManager);
        return xmppHandler;
    }

    public static String getRefreshToken() {
        final String oauth = System.getenv("LANTERN_OAUTH_REFTOKEN");
        if (StringUtils.isBlank(oauth)) {
            return privateProps.getProperty("refresh_token");
        }
        return oauth;
     }

    public static String getAccessToken() {
        final String oauth = System.getenv("LANTERN_OAUTH_ACCTOKEN");
        if (StringUtils.isBlank(oauth)) {
            return privateProps.getProperty("access_token");
        }
        return oauth;
    }

    private static LanternSocketsUtil newLanternSocketsUtil(
        final LanternTrustStore trustStore) {
        final LanternSocketsUtil util = new LanternSocketsUtil(null, trustStore);
        return util;
    }

    public static MessageEvent createDummyMessageEvent(final Object message) {
        return new MessageEvent() {
            @Override
            public Object getMessage() {
                return message;
            }
            
            @Override
            public SocketAddress getRemoteAddress() {
                return null;
            }
            
            @Override
            public Channel getChannel() {
                return null;
            }

            @Override
            public ChannelFuture getFuture() {
                return new DefaultChannelFuture(null, true) {
                    @Override
                    public boolean setFailure(Throwable t) {
                        t.printStackTrace();
                        return true;
                    }
                };
            }
            
            @Override
            public String toString() {
                return "DummyMessageEvent(" + message + ")";
            }
        };
    }

    public static class DummyChannel extends AbstractChannel {
        
        ChannelConfig config;
        
        DummyChannel(final ChannelPipeline p, final ChannelSink sink) {
            super(null, null, p, sink);
            config = new DefaultChannelConfig();
        }
        
        public void simulateConnect() {
            Channels.fireChannelOpen(this);
            Channels.fireChannelBound(this, getLocalAddress());
            Channels.fireChannelConnected(this, getRemoteAddress());                
        }
        
        @Override public ChannelConfig getConfig() {return config;}
        
        @Override public SocketAddress getLocalAddress() { return new InetSocketAddress("127.0.0.1", 55512); }
        @Override public SocketAddress getRemoteAddress() { return new InetSocketAddress("127.0.0.1", 55513); }
        
        @Override public boolean isBound() {return true;}
        @Override public boolean isConnected() {return true;}
    }


    public static DummyChannel createDummyChannel(final ChannelPipeline pipeline) {
        final ChannelSink sink = new AbstractChannelSink() {
            @Override public void eventSunk(ChannelPipeline p, ChannelEvent e) {}
            @Override public void exceptionCaught(ChannelPipeline pipeline,
                                     ChannelEvent e,
                                     ChannelPipelineException cause)
                                     throws Exception {
                                         
                Throwable t = cause.getCause();
                if (t != null) {
                    t.printStackTrace();
                }
                super.exceptionCaught(pipeline,e,cause);
            }
            
        };

        return new DummyChannel(pipeline, sink);
    }

    /**
     * fire up something that looks like a lantern peer locally on the 
     * specified port. Can customized by specifying an extra handler that 
     * replies with an httpresponse / inspects the request. 
     * By default it does nothing aside from accept connections and set up 
     * codecs / ssl etc.
     *
     * @param bindPort local port to bind dummy server on
     * @param ksm if non-null use this to add an ssl context to the server
     * @param handler if non-null add this handler to the pipeline executed by the server
     * 
     */
    public static ServerBootstrap startDummyLanternPeer(final int bindPort, final KeyStoreManager ksm, 
                                                  final ChannelHandler handler) {

        final ChannelFactory chanFactory = new NioServerSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool()
        );
        final ProxyCacheManager cacheManager = new ProxyCacheManager() {

            @Override
            public boolean returnCacheHit(final HttpRequest request, 
                final Channel channel) {
                return false;
            }
            
            @Override
            public Future<String> cache(final HttpRequest originalRequest,
                final HttpResponse httpResponse, 
                final Object response, final ChannelBuffer encoded) {
                return null;
            }
        };

        final ServerBootstrap server = new ServerBootstrap(chanFactory);
        server.setPipelineFactory(
            new ChannelPipelineFactory() {
                @Override
                public ChannelPipeline getPipeline() {
                    ChannelPipeline pipeline = Channels.pipeline();

                    if (ksm != null) {
                        final SslContextFactory scf = new SslContextFactory(ksm);
                        final SSLEngine engine = scf.getServerContext().createSSLEngine();
                        engine.setUseClientMode(false);
                        pipeline.addLast("ssl", new SslHandler(engine));
                    }

                    pipeline.addLast("decoder", 
                        new HttpRequestDecoder(8192, 8192*2, 8192*2));
                    pipeline.addLast("encoder", new ProxyHttpResponseEncoder(cacheManager));

                    // custom handler in place of the normal proxy...
                    if (handler != null) {
                        pipeline.addLast("handler", handler); 
                    }
                    return pipeline; 
                }
            }
        );

        server.bind(new InetSocketAddress(bindPort));
        return server;
    }

    /*
    public static LanternKeyStoreManager createTempKeyStore() {
        File keyStoreRoot = Files.createTempDir(); 
        return new LanternKeyStoreManager(keyStoreRoot);
    }

    /**
     * this mimics the portion of Launcher that starts the local browser proxy, 
     * stubbing out some things.
     */  
    public static LanternHttpProxyServer startMockLanternHttpProxyServer(
        int port, ProxyProvider pp, CookieTracker ct) throws Exception {
        
        ProxyStatusListener psl = new ProxyStatusListener() {
            @Override
            public void onCouldNotConnect(ProxyHolder proxyAddress) {}
            @Override
            public void onCouldNotConnectToPeer(URI peerUri) {}
            @Override
            public void onError(URI peerUri) {}
            @Override
            public void onCouldNotConnectToLae(ProxyHolder proxyAddress) {}
        };
        
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
        
        final SetCookieObserver co = new WhitelistSetCookieObserver(ct);
        final CookieFilter.Factory cf = new DefaultCookieFilterFactory(ct);
        LanternHub.setProxyProvider(pp);
        LanternHub.setProxyStatusListener(psl);
        final LanternHttpProxyServer server = new LanternHttpProxyServer(port, 
            co, cf, serverChannelFactory, clientChannelFactory, timer, channelGroup);
        server.start();
        return server;
        */
        
        return null;
    }

    public static HttpRequest createGetRequest(final String uri) {
        return new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, uri);
    }

    public static HttpRequest createPostRequest(final String uri) {
        return new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.POST, uri);
    }


    public static HttpResponse createResponse() {
        HttpResponse response = new DefaultHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.OK);
        return response;        
    }
    
    public static HttpResponse createResponse(final String content, final ChannelBufferFactory bufferFactory) throws Exception {
        HttpResponse response = createResponse();
        response.setHeader("Content-Type", "text/html;charset=utf-8");
        byte encodedContent[] = content.getBytes("utf-8");
        response.setHeader("Content-Length", encodedContent.length);
        response.setContent(bufferFactory.getBuffer(encodedContent, 0, encodedContent.length));
        return response;
    }

    /**
     * return the default decoding of the http cookie / set-cookie header given 
     * as if it was 
     */ 
    public static Cookie createDefaultCookie(final String headerValue) throws Exception {
        Set<Cookie> cookies = new CookieDecoder().decode(headerValue);
        assertTrue(cookies.size() == 1);
        return cookies.iterator().next();
    }

    public static StoredCookie createSetCookie(final String headerValue, final String uri) throws Exception {
        URI originUri = new URI(uri);
        Set<Cookie> cookies = new CookieDecoder().decode(headerValue);
        assertTrue(cookies.size() == 1);
        Cookie cookie = cookies.iterator().next();
        return StoredCookie.fromSetCookie(cookie, originUri);
    }

    public static Set<Cookie> extractCookies(HttpRequest req) {
        if (req.containsHeader(HttpHeaders.Names.COOKIE)) {
            final String header = req.getHeader(HttpHeaders.Names.COOKIE);
            return new CookieDecoder().decode(header);
        }
        else {
            return new HashSet<Cookie>();
        }
    }

    public static Set<Cookie> extractSetCookies(HttpResponse res) {
        if (res.containsHeader(HttpHeaders.Names.SET_COOKIE)) {
            final List<String> headers = res.getHeaders(HttpHeaders.Names.SET_COOKIE);
            
            final Set<Cookie> cookies = new HashSet<Cookie>();
            for (final String header : headers) {
                cookies.addAll(new CookieDecoder().decode(header));
            }
            return cookies;
        }
        else {
            return new HashSet<Cookie>();
        }
    }

    public static boolean hasCookieNamed(final String cookieName, final Collection<Cookie> cookies) {
        for (Cookie c : cookies) {
            if (c.getName().equals(cookieName)) {
                return true;
            }
        }
        return false;
    }

    public static HttpClientFactory newHttClientFactory() {
        final KeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil =
            new LanternSocketsUtil(null, trustStore);
        
        final Censored censored = new DefaultCensored();
        final HttpClientFactory factory = 
                new HttpClientFactory(socketsUtil, censored, TestingUtils.newProxyTracker());
        return factory;
    }

    public static KeyStoreManager newKeyStoreManager() {
        final File temp = new File(String.valueOf(RandomUtils.nextInt()));
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                try {
                    FileUtils.forceDelete(temp);
                } catch (IOException e) {}
            }
        });
        final KeyStoreManager ksm = new LanternKeyStoreManager(temp);
        return ksm;
    }
}