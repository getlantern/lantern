package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.UnknownHostException;

import javax.net.SocketFactory;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.proxy.ProxyInfo;
import org.jivesoftware.smack.proxy.ProxyInfo.ProxyType;
import org.lantern.util.HttpClientFactory;
import org.littleshoot.commom.xmpp.XmppConfig;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternXmppUtil {


    private final Logger LOG = LoggerFactory.getLogger(getClass());
    private final LanternSocketsUtil socketsUtil;
    private final HttpClientFactory httpClientFactory;
    
    @Inject
    public LanternXmppUtil(final LanternSocketsUtil socketsUtil,
            final HttpClientFactory httpClientFactory) {
        this.socketsUtil = socketsUtil;
        this.httpClientFactory = httpClientFactory;
        XmppConfig.setRetyStrategyFactory(new LanternXmppRetryStrategyFactory());
    }
    
    public ConnectionConfiguration xmppConfig() {
        final ConnectionConfiguration config = xmppConfig(null);
        return config;
    }
    
    private ProxyInfo proxyInfo() {
        final int proxyPort = LanternUtils.getFallbackServerPort();
        final ProxyInfo proxyInfo = 
                new ProxyInfo(ProxyType.HTTP, 
                        LanternUtils.getFallbackServerHost(), 
                    proxyPort, "", "");
        return proxyInfo;
    }

    public ConnectionConfiguration xmppProxyConfig() {

        return xmppConfig(proxyInfo());
    }
    
    public ConnectionConfiguration xmppConfig(final ProxyInfo proxyInfo) {
        final ConnectionConfiguration config;
        if (proxyInfo == null) { 
            config = new ConnectionConfiguration("talk.google.com", 5222, 
                "gmail.com");
            config.setSocketFactory(new DirectSocketFactory());
        } else {
            config = new ConnectionConfiguration("talk.google.com", 5222, 
                "gmail.com", proxyInfo);
            config.setSocketFactory(
                new ProxySocketFactory(this.socketsUtil, proxyInfo));
        }
        
        config.setProxiedHttpClient(this.httpClientFactory.newProxiedClient());
        config.setDirectHttpClient(this.httpClientFactory.newClient());
        
        config.setSslSocketFactory(this.socketsUtil.newTlsSocketFactoryJavaCipherSuites());
        config.setFallbackProxy(proxyInfo);
        config.setExpiredCertificatesCheckEnabled(true);
        
        // We don't check for matching domains because Google Talk uses the
        // same cert for Google Apps domains, and this would always fail in
        // those cases.
        //config.setNotMatchingDomainCheckEnabled(true);
        config.setSendPresence(false);
        
        config.setCompressionEnabled(true);
        
        config.setRosterLoadedAtLogin(true);
        config.setReconnectionAllowed(false);
        config.setVerifyChainEnabled(true);
        config.setVerifyRootCAEnabled(true);
        config.setSelfSignedCertificateEnabled(false);
        //final LanternTrustManager tm = this.keyStoreManager.getTrustManager();
        //config.setTruststorePath(tm.getTruststorePath());
        //config.setTruststorePassword(tm.getTruststorePassword());
        
        //config.setTruststorePath(this.trustStore.getTrustStorePath());
        //config.setTruststorePassword(this.trustStore.getTrustStorePassword());
        
        final String[] cipherSuites = new String[] {
            //"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",
            //"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA",
            //"TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA",
            //"TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_DHE_DSS_WITH_AES_256_CBC_SHA",
            "SSL_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA",
            //"TLS_RSA_WITH_CAMELLIA_256_CBC_SHA",
            //"TLS_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_ECDHE_ECDSA_WITH_RC4_128_SHA",
            //"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA",
            //"TLS_ECDHE_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA",
            //"TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA",
            //"TLS_DHE_DSS_WITH_RC4_128_SHA",
            //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_DHE_DSS_WITH_AES_128_CBC_SHA",
            //"TLS_ECDH_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_ECDH_ECDSA_WITH_RC4_128_SHA",
            //"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA",
            //"TLS_RSA_WITH_SEED_CBC_SHA",
            //"TLS_RSA_WITH_CAMELLIA_128_CBC_SHA",
            //"TLS_RSA_WITH_RC4_128_MD5",
            //"TLS_RSA_WITH_RC4_128_SHA",
            //"TLS_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA",
            //"TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA",
            //"SSL_RSA_FIPS_WITH_3DES_EDE_CBC_SHA",
            //"TLS_RSA_WITH_3DES_EDE_CBC_SHA",
        };
        config.setCipherSuites(cipherSuites);
        return config;
    }
    
    private final class DirectSocketFactory extends SocketFactory {
        
        @Override
        public Socket createSocket(final InetAddress host, final int port, 
            final InetAddress localHost, final int localPort) 
            throws IOException {
            // We ignore the local port binding.
            return createSocket(host, port);
        }
        
        @Override
        public Socket createSocket(final String host, final int port, 
            final InetAddress localHost, final int localPort)
            throws IOException, UnknownHostException {
            // We ignore the local port binding.
            return createSocket(host, port);
        }
        
        @Override
        public Socket createSocket(final InetAddress host, final int port) 
            throws IOException {
            final SocketAddress isa = new InetSocketAddress(host, port);
            LOG.info("Creating socket to {}", isa);
            final Socket sock = new Socket();
            sock.connect(isa, 40000);
            LOG.info("Socket connected to {}",isa);
            return sock;
        }
        
        @Override
        public Socket createSocket(final String host, final int port) 
            throws IOException, UnknownHostException {
            LOG.info("Creating socket");
            return createSocket(InetAddress.getByName(host), port);
        }
    }
    
    public void configureXmpp() {
        XmppUtils.setGlobalConfig(xmppConfig(null));
    }

    public void configureXmppWithBackupProxy() {
        XmppUtils.setGlobalConfig(xmppProxyConfig());
    }
}
