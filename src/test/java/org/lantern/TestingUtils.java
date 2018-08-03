package org.lantern;

import static org.junit.Assert.*;
import io.netty.handler.codec.http.DefaultHttpRequest;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpVersion;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.security.Security;
import java.util.Properties;
import java.util.Queue;
import java.util.concurrent.Callable;

import javax.net.ssl.SSLEngine;
import javax.security.auth.login.CredentialException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.cli.UnrecognizedOptionException;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.HttpHost;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.RandomRoutingTable;
import org.lantern.endpoints.FriendApi;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.kscope.DefaultKscopeAdHandler;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.NetworkTracker;
import org.lantern.oauth.OauthUtils;
import org.lantern.oauth.RefreshToken;
import org.lantern.proxy.GetModeProxy;
import org.lantern.proxy.UdtServerFiveTupleListener;
import org.lantern.state.DefaultFriendsHandler;
import org.lantern.state.DefaultModelUtils;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Settings;
import org.lantern.util.HttpClientFactory;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;
import org.littleshoot.proxy.ChainedProxyManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class TestingUtils {
    private static final Logger LOGGER = LoggerFactory.getLogger(TestingUtils.class);
    
    private static final File privatePropsFile;

    private static final Properties privateProps = new Properties();
    
    private static final HttpHost EXPECTED_PROXY = new HttpHost("127.0.0.1",
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT,
            "http");
    
    static {
        Security.addProvider(new BouncyCastleProvider());
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
        final Model model = new Model(newCountryService());
        model.getSettings().setRefreshToken(getRefreshToken());
        return model;
    }
    
    public static CountryService newCountryService() {
        final Censored censored = new DefaultCensored();
        return new CountryService(censored);
    }

    public static XmppHandler newXmppHandler() throws IOException, CredentialException {
        final Censored censored = new DefaultCensored();
        final Model mod = new Model(new CountryService(censored));
        final Settings set = mod.getSettings();
        set.setAccessToken(accessToken());
        set.setRefreshToken(getRefreshToken());
        set.setUseGoogleOAuth2(true);
        return newXmppHandler(censored, mod);
    }

    public static XmppHandler newXmppHandler(final Censored censored, 
            final Model model) throws IOException {
        
        final LanternKeyStoreManager ksm = newKeyStoreManager();
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
        
        final HttpClientFactory httpClientFactory = TestingUtils.newHttClientFactory();
        final OauthUtils oauth = new OauthUtils(httpClientFactory, model, new RefreshToken(model));
        final FriendApi api = new FriendApi(oauth, model);
        
        final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker = new NetworkTracker<String, URI, ReceivedKScopeAd>();
        final FriendsHandler friendsHandler = 
                new DefaultFriendsHandler(model, api, null, null, networkTracker, new Messages(new Model()));
        final Roster roster = new Roster(routingTable, model, censored, friendsHandler);
        
        final GeoIpLookupService geoIpLookupService = new GeoIpLookupService();
        
        final PeerFactory peerFactory = 
            new DefaultPeerFactory(geoIpLookupService, model, roster);
        final ProxyTracker proxyTracker = 
            new DefaultProxyTracker(model, peerFactory, trustStore);
        final KscopeAdHandler kscopeAdHandler = 
            new DefaultKscopeAdHandler(proxyTracker, trustStore, routingTable, 
                networkTracker);
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
        
        final ProxySocketFactory proxySocketFactory = new ProxySocketFactory();
        final LanternXmppUtil xmppUtil = new LanternXmppUtil(socketsUtil, 
                proxySocketFactory);
        
        final XmppHandler xmppHandler = new DefaultXmppHandler(model,
            updateTimer, stats, ksm, socketsUtil, xmppUtil, modelUtils,
            roster, proxyTracker, kscopeAdHandler, natPmpService, upnpService,
            new UdtServerFiveTupleListener(null, model),
            friendsHandler, networkTracker, censored);
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

    public static HttpRequest createGetRequest(final String uri) {
        return new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, uri);
    }

    public static HttpRequest createPostRequest(final String uri) {
        return new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.POST, uri);
    }


    public static HttpClientFactory newHttClientFactory() {
        final Censored censored = new DefaultCensored();
        final HttpClientFactory factory = 
                new HttpClientFactory(censored);
        return factory;
    }

    public static LanternKeyStoreManager newKeyStoreManager() {
        // We do all this temp and random file stuff below to avoid multiple
        // tests clobbering each other.
        final File ksmFile = new File(System.getProperty("java.io.tmpdir"), 
                String.valueOf(RandomUtils.nextLong()));
        ksmFile.mkdirs();
        try {
            FileUtils.forceDeleteOnExit(ksmFile);
        } catch (IOException e) {
        }
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager(
                ksmFile);
        return ksm;
    }

    public static String accessToken() throws IOException, CredentialException {
        final DefaultHttpClient httpClient = new DefaultHttpClient();
        final OauthUtils utils = newOauthUtils();
        return utils.oauthTokens(httpClient, getRefreshToken()).getAccessToken();
    }

    private static OauthUtils newOauthUtils() {
        final Model mod = new Model();
        return new OauthUtils(newHttClientFactory(), mod, new RefreshToken(mod));
    }

    public static CommandLine newCommandLine() throws Exception {
        return newCommandLine(new String[]{});
    }

    public static CommandLine newCommandLine(final String[] args) throws Exception {
        final Options options = Cli.buildOptions();
        final CommandLineParser parser = new PosixParser();
        final CommandLine cmd = parser.parse(options, args);
        if (cmd.getArgs().length > 0) {
            throw new UnrecognizedOptionException("Extra arguments were provided");
        }
        return cmd;
    }
    
    /**
     * Starts a GetModeProxy using the default fallback server, does the given
     * work and stops the GetModeProxy.
     * 
     * @param work
     * @return
     */
    public static <T> T doWithGetModeProxy(Callable<T> work) throws Exception {
        Censored censored = new DefaultCensored();
        CountryService countryService = new CountryService(censored);
        Model model = new Model(countryService);

        //assume that we are connected to the Internet
        model.getConnectivity().setInternet(true);

        LanternKeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        ClientStats clientStats = new StatsStub();
        ChainedProxyManager proxyManager =
                new ChainedProxyManager() {
            @Override
            public void lookupChainedProxies(HttpRequest httpRequest,
                    Queue<ChainedProxy> chainedProxies) {
                chainedProxies.add(new ChainedProxyAdapter() {
                    @Override
                    public InetSocketAddress getChainedProxyAddress() {
                        return new InetSocketAddress("54.254.96.14", 16589);
                    }
                    
                    @Override
                    public boolean requiresEncryption() {
                        return true;
                    }
                    
                    @Override
                    public SSLEngine newSslEngine() {
                        return trustStore.newSSLEngine();
                    }
                });
            }
        };
        GetModeProxy getModeProxy = new GetModeProxy(clientStats, proxyManager);
        getModeProxy.start();
        try {
            return work.call();
        } finally {
            try {
                getModeProxy.stop();
            } catch (Exception e) {
                LOGGER.warn("Unable to stop GetModeProxy - this may cause failures on subsequent tests");
            }
        }
    }
    
    public static void assertIsUsingGetModeProxy(HttpClient httpClient) {
        assertEquals(EXPECTED_PROXY,
                httpClient.getParams().getParameter(ConnRoutePNames.DEFAULT_PROXY));
    }
}
