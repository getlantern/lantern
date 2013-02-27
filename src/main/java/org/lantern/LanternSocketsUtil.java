package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

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
        private final AtomicInteger threadNumber = new AtomicInteger();

        @Override
        public Thread newThread(final Runnable r) {
            final Thread t = new Thread(r, "Peer-Reading-Thread-"+threadNumber);
            t.setDaemon(true);
            threadNumber.incrementAndGet();
            return t;
        }
    });

    private final LanternTrustStore trustStore;

    @Inject
    public LanternSocketsUtil(final Stats stats,
        final LanternTrustStore trustStore) {
        this.stats = stats;
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
        return this.trustStore.getContext().getServerSocketFactory();
    }

    public SSLSocketFactory newTlsSocketFactoryJavaCipherSuites() {
        log.debug("Creating TLS socket factory with default java cipher suites");
        return newTlsSocketFactory(null);
    }

    public SSLSocketFactory newTlsSocketFactory() {
        log.debug("Creating TLS socket factory");
        return newTlsSocketFactory(IceConfig.getCipherSuites());
    }

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
                sock.setNeedClientAuth(true);
                if (cipherSuites != null && cipherSuites.length > 0) {
                    sock.setEnabledCipherSuites(cipherSuites);
                }
            }
        };
    }

    private SSLSocketFactory sf() {
        return trustStore.getContext().getSocketFactory();
    }

    public void startReading(final Socket sock, final Channel channel,
        final boolean recordStats) {
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                final byte[] buffer = new byte[4096];
                int n = 0;
                try {
                    log.debug("READING FROM SOCKET: {}", sock);
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
