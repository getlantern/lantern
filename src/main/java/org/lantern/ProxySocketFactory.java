package org.lantern;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.net.SocketFactory;

import org.jivesoftware.smack.proxy.ProxyInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 * {@link SocketFactory} for creating sockets through an HTTP proxy.
 * 
 * HTTPProxySocketFactory
 */
@Singleton
public class ProxySocketFactory extends SocketFactory {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(ProxySocketFactory.class);
    private static final Pattern RESPONSE_PATTERN = Pattern
            .compile("HTTP/\\S+\\s(\\d+)\\s(.*)\\s*");

    @Override
    public Socket createSocket(String host, int port) throws IOException,
            UnknownHostException {
        return httpConnectSocket(host, port);
    }

    @Override
    public Socket createSocket(final String host, final int port,
            final InetAddress localHost, final int localPort)
            throws IOException,
            UnknownHostException {
        return httpConnectSocket(host, port);
    }

    @Override
    public Socket createSocket(final InetAddress host, final int port)
            throws IOException {
        return httpConnectSocket(host.getHostAddress(), port);
    }

    @Override
    public Socket createSocket(final InetAddress address, final int port,
            final InetAddress localAddress, final int localPort)
            throws IOException {
        return httpConnectSocket(address.getHostAddress(), port);
    }

    /**
     * <p>
     * Establishes a {@link Socket} to the given host and port by doing an HTTP
     * CONNECT tunnel using our proxy. This does not take care of TLS
     * negotiating, that is handled by the user of the returned {@link Socket}.
     * </p>
     * 
     * @param host
     * @param port
     * @return
     * @throws IOException
     */
    private Socket httpConnectSocket(final String host, final int port)
            throws IOException {
        final String proxyHost = "127.0.0.1";
        final int proxyPort = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
        LanternUtils.waitForServer(proxyHost, proxyPort, 10000);
        LOGGER.debug("Opening CONNECT tunnel to {}:{} using proxy at {}:{}",
                host,
                port,
                proxyHost,
                proxyPort);
        Socket socket = new Socket(proxyHost, proxyPort);
        
        final String url = "CONNECT " + host + ":" + port;
        socket.getOutputStream().write(
            (url + " HTTP/1.1\r\nHost: " + url + "\r\n\r\n").getBytes("UTF-8"));

        final InputStream in = socket.getInputStream();
        final StringBuilder got = new StringBuilder(100);
        int nlchars = 0;

        while (true) {
            final int c = in.read();
            got.append((char) c);
            if (got.length() > 4096) {
                throw new ProxyException(ProxyInfo.ProxyType.HTTP, "Recieved " +
                    "header of "+got.length()+" characters from " + proxyHost +
                    ", cancelling connection:\n"+got.toString());
            }
            if (c == -1) {
                throw new ProxyException(ProxyInfo.ProxyType.HTTP);
            }
            if ((nlchars == 0 || nlchars == 2) && c == '\r') {
                nlchars++;
            } else if ((nlchars == 1 || nlchars == 3) && c == '\n') {
                nlchars++;
            } else {
                nlchars = 0;
            }
            if (nlchars == 4) {
                break;
            }
        }

        if (nlchars != 4) {
            throw new ProxyException(ProxyInfo.ProxyType.HTTP, "Never " +
                "received blank line from " + proxyHost +
                ", cancelling connection");
        }

        final String gotstr = got.toString();

        final BufferedReader br = new BufferedReader(new StringReader(gotstr));
        final String response = br.readLine();

        if (response == null) {
            throw new ProxyException(ProxyInfo.ProxyType.HTTP, "Empty proxy "
                    + "response from " + proxyHost + ", cancelling");
        }

        final Matcher m = RESPONSE_PATTERN.matcher(response);
        if (!m.matches()) {
            throw new ProxyException(ProxyInfo.ProxyType.HTTP, "Unexpected "
                    + "proxy response from " + proxyHost + ": " + response);
        }

        final int code = Integer.parseInt(m.group(1));

        if (code != HttpURLConnection.HTTP_OK) {
            throw new ProxyException(ProxyInfo.ProxyType.HTTP);
        }

        return socket;
    }
}
