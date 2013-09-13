package org.lantern;

import static org.mockito.Mockito.mock;
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
import java.net.URISyntaxException;
import java.util.Properties;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.client.HttpClient;
import org.apache.http.impl.client.DefaultHttpClient;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.RandomRoutingTable;
import org.lantern.endpoints.FriendApi;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.http.OauthUtils;
import org.lantern.kscope.DefaultKscopeAdHandler;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.proxy.UdtServerFiveTupleListener;
import org.lantern.state.DefaultFriendsHandler;
import org.lantern.state.DefaultModelUtils;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Peer.Type;
import org.lantern.state.Settings;
import org.lantern.stubs.PeerFactoryStub;
import org.lantern.stubs.ProxyTrackerStub;
import org.lantern.ui.NotificationManager;
import org.lantern.util.HttpClientFactory;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;

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
        final Model model = new Model(newCountryService());
        model.getSettings().setRefreshToken(getRefreshToken());
        return model;
    }
    
    public static CountryService newCountryService() {
        final Censored censored = new DefaultCensored();
        return new CountryService(censored);
    }

    public static XmppHandler newXmppHandler() throws IOException {
        final Censored censored = new DefaultCensored();
        final Model mod = new Model(new CountryService(censored));
        final Settings set = mod.getSettings();
        set.setAccessToken(accessToken());
        set.setRefreshToken(getRefreshToken());
        set.setUseGoogleOAuth2(true);
        return newXmppHandler(censored, mod);
    }

    public static ProxyTracker newProxyTracker() {
        final PeerFactory peerFactory = new PeerFactoryStub();
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        
        return new ProxyTrackerStub() {
            @Override
            public ProxyHolder firstConnectedProxy() {
                final InetSocketAddress tuple = 
                    new InetSocketAddress("54.254.96.14", 16589);
                final URI uri;
                try {
                    uri = new URI("fallback@getlantern.org");
                } catch (URISyntaxException e) {
                    return null;
                }
                return new ProxyHolder(
                        this, peerFactory, trustStore,
                        uri, tuple, Type.cloud);
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
        
        final HttpClientFactory httpClientFactory = TestingUtils.newHttClientFactory();
        final OauthUtils oauth = new OauthUtils(httpClientFactory, model);
        final FriendApi api = new FriendApi(oauth);
        
        final FriendsHandler friendsHandler = 
                new DefaultFriendsHandler(model, api, null);
        final Roster roster = new Roster(routingTable, model, censored, friendsHandler);
        
        final GeoIpLookupService geoIpLookupService = new GeoIpLookupService();
        
        final PeerFactory peerFactory = 
            new DefaultPeerFactory(geoIpLookupService, model, roster);
        final ProxyTracker proxyTracker = 
            new DefaultProxyTracker(model, peerFactory, null, trustStore);
        final KscopeAdHandler kscopeAdHandler = 
            new DefaultKscopeAdHandler(proxyTracker, trustStore, routingTable, 
                null, model, friendsHandler);
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

        
        //final HttpClientFactory httpClientFactory = 
                //new HttpClientFactory(socketsUtil, censored, TestingUtils.newProxyTracker());
        
        final XmppHandler xmppHandler = new DefaultXmppHandler(model,
            updateTimer, stats, ksm, socketsUtil, xmppUtil, modelUtils,
            roster, proxyTracker, kscopeAdHandler, natPmpService, upnpService,
            notificationManager, new UdtServerFiveTupleListener(null),
            friendsHandler);
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
        final LanternKeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil =
            new LanternSocketsUtil(null, trustStore);
        
        final Censored censored = new DefaultCensored();
        final HttpClientFactory factory = 
                new HttpClientFactory(socketsUtil, censored, TestingUtils.newProxyTracker());
        return factory;
    }

    public static LanternKeyStoreManager newKeyStoreManager() {
        final File temp = new File(String.valueOf(RandomUtils.nextInt()));
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                try {
                    FileUtils.forceDelete(temp);
                } catch (IOException e) {}
            }
        });
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager(temp);
        return ksm;
    }

    public static String accessToken() throws IOException {
        final HttpClient httpClient = new DefaultHttpClient();
        return OauthUtils.oauthTokens(httpClient, getRefreshToken()).getAccessToken();
    }    
}
