package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.UnknownHostException;

import javax.net.SocketFactory;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.littleshoot.commom.xmpp.XmppConfig;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategyFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternXmppUtil {


    private final Logger LOG = LoggerFactory.getLogger(getClass());
    private final ProxySocketFactory proxySocketFactory;
    
    @Inject
    public LanternXmppUtil(
            final ProxySocketFactory proxySocketFactory,
            final XmppConnectionRetyStrategyFactory retryStrategy) {
        this.proxySocketFactory = proxySocketFactory;
        XmppConfig.setRetyStrategyFactory(retryStrategy);
    }
    
    public ConnectionConfiguration xmppConfig(boolean proxied) {
        final ConnectionConfiguration config = 
                new ConnectionConfiguration("talk.google.com", 5222, 
                "gmail.com");
        SocketFactory socketFactory =
                proxied ? proxySocketFactory : new DirectSocketFactory();
        config.setSocketFactory(socketFactory);
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
    
    /**
     * TODO: Where does this actually use our trust store? Seems like this
     * will trust the default certs?
     */
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
}
