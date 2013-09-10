package org.lantern;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.net.SocketFactory;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.proxy.ProxyInfo;
import org.jivesoftware.smack.util.Base64;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * {@link SocketFactory} for creating sockets through an HTTP proxy.
 * 
 * HTTPProxySocketFactory
 */
@Singleton
public class ProxySocketFactory extends SocketFactory {

    //private final SSLSocketFactory socketFactory;
    private final ProxyTracker proxyTracker;
    private final LanternSocketsUtil socketsUtil;

    @Inject
    public ProxySocketFactory(final LanternSocketsUtil socketsUtil, 
            final ProxyTracker proxyTracker) {
        this.socketsUtil = socketsUtil;
        this.proxyTracker = proxyTracker;
        //this.socketFactory = socketsUtil.newTlsSocketFactory();
    }

    @Override
    public Socket createSocket(String host, int port) throws IOException,
            UnknownHostException {
        return httpConnectSocket(host, port);
    }

    @Override
    public Socket createSocket(final String host, final int port,
        final InetAddress localHost, final int localPort) throws IOException,
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
        final InetAddress localAddress, final int localPort) throws IOException {
        return httpConnectSocket(address.getHostAddress(), port);
    }

    private Socket httpConnectSocket(final String host, final int port)
        throws IOException {
        final ProxyHolder ph = proxyTracker.firstConnectedProxy();
        final InetSocketAddress isa = ph.getFiveTuple().getRemote();
        final String proxyHost = isa.getAddress().getHostAddress();
        final int proxyPort = isa.getPort();
        //final Socket sock = this.socketFactory.createSocket();
        final Socket sock = socketsUtil.newTlsSocketFactoryJavaCipherSuites().createSocket();
        sock.connect(new InetSocketAddress(proxyHost, proxyPort), 50 * 1000);
        final String url = "CONNECT " + host + ":" + port;
        String proxyLine;
        final String user = ph.getProxyUsername();
        if (StringUtils.isBlank(user)) {
            proxyLine = "";
        } else {
            final String password = ph.getProxyPassword();
            proxyLine = "\r\nProxy-Authorization: Basic "
                    + new String(Base64.encodeBytes((user + ":" + password)
                            .getBytes("UTF-8")));
        }
        sock.getOutputStream().write(
            (url + " HTTP/1.1\r\nHost: " + url + proxyLine + "\r\n\r\n").getBytes("UTF-8"));

        final InputStream in = sock.getInputStream();
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

        return sock;
    }

    private static final Pattern RESPONSE_PATTERN
        = Pattern.compile("HTTP/\\S+\\s(\\d+)\\s(.*)\\s*");

}
