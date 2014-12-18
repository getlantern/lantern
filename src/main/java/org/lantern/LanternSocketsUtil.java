package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.UnknownHostException;

import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.lantern.proxy.ProxyHolder;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Utility class for creating SSL/TLS sockets that use the SSL engine from
 * LanternTrustStore. That ensures we only visit sites with explicitl 
 * trusted/pinned certificates to avoid MITM attacks from adversaries capable
 * of compromising CAs.
 * 
 * In practice this particular class is really only used for Google Talk
 * connections while all other sockets are created through the rather
 * obscure call to {@link LanternTrustStore} newSSLEngine from within
 * {@link ProxyHolder}.
 */
@Singleton
public class LanternSocketsUtil {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final LanternTrustStore trustStore;

    @Inject
    public LanternSocketsUtil(final LanternTrustStore trustStore) {
        this.trustStore = trustStore;
    }


    public SSLServerSocketFactory newTlsServerSocketFactoryJavaCipherSuites() {
        log.debug("Creating TLS server socket factory with default java " +
            "cipher suites");
        return newTlsServerSocketFactory(null);
    }

    public SSLServerSocketFactory newTlsServerSocketFactory() {
        log.debug("Creating TLS server socket factory");
        return newTlsServerSocketFactory(IceConfig.getCipherSuites());
    }

    public SSLServerSocketFactory newTlsServerSocketFactory(
        final String[] cipherSuites) {
        log.debug("Creating TLS server socket factory");
        return wrappedServerSocketFactory(cipherSuites);
    }

    private SSLServerSocketFactory wrappedServerSocketFactory(
        final String[] cipherSuites) {
        return new SSLServerSocketFactory() {
            @Override
            public ServerSocket createServerSocket() throws IOException {
                final SSLServerSocket ssl =
                    (SSLServerSocket) ssf().createServerSocket();
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port,
                final int backlog, final InetAddress ifAddress)
                throws IOException {
                final SSLServerSocket ssl =
                    (SSLServerSocket) ssf().createServerSocket(port, backlog,
                        ifAddress);
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port,
                final int backlog) throws IOException {
                final SSLServerSocket ssl =
                    (SSLServerSocket) ssf().createServerSocket(port, backlog);
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port)
                throws IOException {
                final SSLServerSocket ssl =
                    (SSLServerSocket) ssf().createServerSocket(port);
                configure(ssl);
                return ssl;
            }
            @Override
            public String[] getDefaultCipherSuites() {
                return ssf().getDefaultCipherSuites();
            }
            @Override
            public String[] getSupportedCipherSuites() {
                return ssf().getSupportedCipherSuites();
            }

            private void configure(final SSLServerSocket ssl) {
                ssl.setNeedClientAuth(true);
                if (cipherSuites != null && cipherSuites.length > 0) {
                    ssl.setEnabledCipherSuites(cipherSuites);
                }
            }
        };
    }

    protected SSLServerSocketFactory ssf() {
        return this.trustStore.getSslContext().getServerSocketFactory();
    }

    public SSLSocketFactory newTlsSocketFactoryJavaCipherSuites() {
        log.debug("Creating TLS socket factory with default java cipher suites");
        return newTlsSocketFactory(null);
    }

    /**
     * Returns a new SSL socket factory. Note that we need to recreate a 
     * complete socket factory in many cases, particularly when connecting
     * to peers, because we dynamically add new trusted peer certificates to our
     * trust store over the course of running, so we need new socket factories
     * that reflect the most recent trust information.
     * 
     * @return A socket factory with the most up to date trust store data.
     */
    /*
    public SSLSocketFactory newTlsSocketFactory() {
        log.debug("Creating TLS socket factory");
        return newTlsSocketFactory(IceConfig.getCipherSuites());
    }
    */

    public SSLSocketFactory newTlsSocketFactory(final String[] cipherSuites) {
        log.debug("Creating TLS socket factory");
        return wrappedSocketFactory(cipherSuites);
    }

    private SSLSocketFactory wrappedSocketFactory(final String[] cipherSuites) {
        return new SSLSocketFactory() {
            @Override
            public Socket createSocket() throws IOException {
                final SSLSocket sock = (SSLSocket) sf().createSocket();
                configure(sock);
                return sock;
            }

            @Override
            public Socket createSocket(final InetAddress address,
                final int port, final InetAddress localAddress,
                final int localPort) throws IOException {
                final SSLSocket sock =
                    (SSLSocket) sf().createSocket(address, port, localAddress, localPort);
                configure(sock);
                return sock;
            }

            @Override
            public Socket createSocket(final String host, final int port,
                final InetAddress localHost, final int localPort)
                throws IOException, UnknownHostException {
                final SSLSocket sock =
                    (SSLSocket) sf().createSocket(host, port, localHost, localPort);
                configure(sock);
                return sock;
            }

            @Override
            public Socket createSocket(final InetAddress host,
                final int port) throws IOException {
                final SSLSocket sock = (SSLSocket) sf().createSocket(host, port);
                configure(sock);
                return sock;
            }

            @Override
            public Socket createSocket(final String host, final int port)
                throws IOException, UnknownHostException {
                final SSLSocket sock = (SSLSocket) sf().createSocket(host, port);
                configure(sock);
                return sock;
            }

            @Override
            public Socket createSocket(final Socket s, final String host,
                final int port, final boolean autoClose) throws IOException {
                final SSLSocket sock =
                    (SSLSocket) sf().createSocket(s, host, port, autoClose);
                configure(sock);
                return sock;
            }

            @Override
            public String[] getDefaultCipherSuites() {
                return sf().getDefaultCipherSuites();
            }

            @Override
            public String[] getSupportedCipherSuites() {
                return sf().getSupportedCipherSuites();
            }

            private void configure(final SSLSocket sock) {
                sock.setUseClientMode(true);
                if (cipherSuites != null && cipherSuites.length > 0) {
                    sock.setEnabledCipherSuites(cipherSuites);
                }
            }
        };
    }

    private SSLSocketFactory sf() {
        return trustStore.getSslContext().getSocketFactory();
    }
    
}
