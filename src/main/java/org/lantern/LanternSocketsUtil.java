package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.UnknownHostException;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.Security;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternSocketsUtil {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Stats stats;
    
    private final ExecutorService threadPool = 
        Executors.newCachedThreadPool(new ThreadFactory() {
        private volatile int threadNumber = 0;
        
        @Override
        public Thread newThread(final Runnable r) {
            final Thread t = new Thread(r, "Peer-Reading-Thread-"+threadNumber);
            t.setDaemon(true);
            threadNumber++;
            return t;
        }
    });

    private final LanternKeyStoreManager ksm;

    @Inject
    public LanternSocketsUtil(final Stats stats, 
        final LanternKeyStoreManager keyStoreManager) {
        this.stats = stats;
        this.ksm = keyStoreManager;
    }
    

    public SSLServerSocketFactory newTlsServerSocketFactory() {
        log.info("Creating TLS server socket factory");
        try {
            final KeyManagerFactory kmf = loadKeyManagerFactory(getSslAlgorithm());
            
            // Initialize the SSLContext to work with our key managers.
            final SSLContext serverContext = SSLContext.getInstance("TLS");
            
            // TODO: We probably still need our own trust manager to verify
            // peer certs.
            //serverContext.init(kmf.getKeyManagers(), ksm.getTrustManagers(), null);
            serverContext.init(kmf.getKeyManagers(), null, null);
            return wrappedServerSocketFactory(serverContext.getServerSocketFactory());
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final KeyManagementException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        }
    }

    private String getSslAlgorithm() {
        String algorithm = 
            Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }
        return algorithm;
    }

    private KeyManagerFactory loadKeyManagerFactory(final String algorithm) {
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(ksm.keyStoreAsInputStream(), ksm.getKeyStorePassword());
            
            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(algorithm);
            kmf.init(ks, ksm.getCertificatePassword());
            return kmf;
        } catch (final KeyStoreException e) {
            throw new Error("Key manager issue", e);
        } catch (final UnrecoverableKeyException e) {
            throw new Error("Key manager issue", e);
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Key manager issue", e);
        } catch (final CertificateException e) {
            throw new Error("Key manager issue", e);
        } catch (final IOException e) {
            throw new Error("Key manager issue", e);
        }
    }

    private static SSLServerSocketFactory wrappedServerSocketFactory(
        final SSLServerSocketFactory ssf) {
        return new SSLServerSocketFactory() {
            @Override
            public ServerSocket createServerSocket() throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket();
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port, 
                final int backlog, final InetAddress ifAddress) 
                throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket(port, backlog, ifAddress);
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port, 
                final int backlog) throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket(port, backlog);
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port) 
                throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket(port);
                configure(ssl);
                return ssl;
            }
            @Override
            public String[] getDefaultCipherSuites() {
                return ssf.getDefaultCipherSuites();
            }
            @Override
            public String[] getSupportedCipherSuites() {
                return ssf.getSupportedCipherSuites();
            }
            
            private void configure(final SSLServerSocket ssl) {
                ssl.setNeedClientAuth(true);
                final String[] suites = IceConfig.getCipherSuites();
                if (suites != null && suites.length > 0) {
                    ssl.setEnabledCipherSuites(suites);
                }
            }
        };
    }


    public SSLSocketFactory newTlsSocketFactory() {
        log.info("Creating TLS socket factory");
        try {
            final SSLContext clientContext = SSLContext.getInstance("TLS");
            final KeyManagerFactory kmf = loadKeyManagerFactory(getSslAlgorithm());
            
            clientContext.init(kmf.getKeyManagers(), ksm.getTrustManagers(), null);
            return wrappedSocketFactory(clientContext.getSocketFactory());
        } catch (final NoSuchAlgorithmException e) {
            log.error("No TLS?", e);
            throw new Error("No TLS?", e);
        } catch (final KeyManagementException e) {
            log.error("Key managmement issue?", e);
            throw new Error("Key managmement issue?", e);
        }
    }

    private SSLSocketFactory wrappedSocketFactory(final SSLSocketFactory sf) {
        return new SSLSocketFactory() {
            @Override
            public Socket createSocket() throws IOException {
                final SSLSocket sock = (SSLSocket) sf.createSocket();
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final InetAddress address, 
                final int port, final InetAddress localAddress, 
                final int localPort) throws IOException {
                final SSLSocket sock = 
                    (SSLSocket) sf.createSocket(address, port, localAddress, localPort);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final String host, final int port, 
                final InetAddress localHost, final int localPort) 
                throws IOException, UnknownHostException {
                final SSLSocket sock = 
                    (SSLSocket) sf.createSocket(host, port, localHost, localPort);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final InetAddress host, 
                final int port) throws IOException {
                final SSLSocket sock = (SSLSocket) sf.createSocket(host, port);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final String host, final int port) 
                throws IOException, UnknownHostException {
                final SSLSocket sock = (SSLSocket) sf.createSocket(host, port);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final Socket s, final String host, 
                final int port, final boolean autoClose) throws IOException {
                final SSLSocket sock = 
                    (SSLSocket) sf.createSocket(s, host, port, autoClose);
                configure(sock);
                return sock;
            }

            @Override
            public String[] getDefaultCipherSuites() {
                return sf.getDefaultCipherSuites();
            }

            @Override
            public String[] getSupportedCipherSuites() {
                return sf.getSupportedCipherSuites();
            }
            
            private void configure(final SSLSocket sock) {
                sock.setNeedClientAuth(true);
                final String[] suites = IceConfig.getCipherSuites();
                if (suites != null && suites.length > 0) {
                    sock.setEnabledCipherSuites(suites);
                }
            }

        };
    }
    
    public void startReading(final Socket sock, final Channel channel, 
        final boolean recordStats) {
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                final byte[] buffer = new byte[4096];
                int n = 0;
                try {
                    log.info("READING FROM SOCKET: {}", sock);
                    if (sock.isClosed()) {
                        log.error("SOCKET IS CLOSED");
                        ProxyUtils.closeOnFlush(channel);
                        return;
                    }
                    final InputStream is = sock.getInputStream();
                    while (-1 != (n = is.read(buffer))) {
                        //log.info("Writing response data: {}", new String(buffer, 0, n));
                        // We need to make a copy of the buffer here because
                        // the writes are asynchronous, so the bytes can
                        // otherwise get scrambled.
                        final ChannelBuffer buf =
                            ChannelBuffers.copiedBuffer(buffer, 0, n);
                        channel.write(buf);
                        if (recordStats) {
                            stats.addDownBytesFromPeers(n);
                        }
                        
                    }
                    ProxyUtils.closeOnFlush(channel);

                } catch (final IOException e) {
                    log.info("Exception relaying peer data back to browser", e);
                    ProxyUtils.closeOnFlush(channel);
                    
                    // The other side probably just closed the connection!!
                    
                    //channel.close();
                    //proxyStatusListener.onError(peerUri);
                    
                }
            }
        };
        threadPool.execute(runner);
    }
}
