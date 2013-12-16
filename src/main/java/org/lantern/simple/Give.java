package org.lantern.simple;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.handler.codec.http.DefaultFullHttpResponse;
import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;
import io.netty.handler.codec.http.HttpResponseStatus;
import io.netty.handler.codec.http.HttpVersion;

import java.net.InetSocketAddress;
import java.nio.charset.Charset;
import java.util.Date;
import java.util.UUID;

import org.lantern.proxy.GetModeHttpFilters;
import org.lantern.proxy.GiveModeHttpFilters;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * A really basic Give mode proxy that listens with both TCP and UDT and trusts
 * all Get proxies.
 * </p>
 * 
 * <p>
 * Run like this:
 * </p>
 * 
 * <pre>
 * ./launch org.lantern.simple.Give 46000 ../too-many-secrets/littleproxy_keystore.jks
 * </pre>
 */
public class Give {
    private static final Logger LOG = LoggerFactory.getLogger(Give.class);

    private String host;
    private int httpsPort;
    private int httpPort;
    private int udtPort;
    private String keyStorePath;
    private String expectedAuthToken;
    private HttpProxyServer server;

    public static void main(String[] args) throws Exception {
        new Give(args).start();
    }

    public Give(String[] args) {
        this.host = args[0];
        this.httpPort = Integer.parseInt(args[1]);
        this.httpsPort = Integer.parseInt(args[2]);
        this.udtPort = Integer.parseInt(args[3]);
        this.keyStorePath = args[4];
        this.expectedAuthToken = args[5];
    }

    public void start() {
        startTcp();
        startUdt();

    }

    private void startTcp() {
        LOG.info("Starting Plain Text Give proxy at TCP port {}", httpPort);
        DefaultHttpProxyServer.bootstrap()
                .withName("Give-PlainText")
                .withPort(httpPort)
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(true)
                // Use a filter to respond with 404 to http requests
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(HttpRequest originalRequest) {
                        return new GiveModeHttpFilters(originalRequest) {
                            @Override
                            public HttpResponse requestPre(HttpObject httpObject) {
                                if (httpObject instanceof HttpRequest) {
                                    return mimicApache(
                                            (HttpRequest) httpObject,
                                            httpPort);
                                }
                                return super.requestPre(httpObject);
                            }
                        };
                    }
                })
                .start();

        LOG.info(
                "Starting TLS Give proxy at TCP port {}", httpPort);
        server = DefaultHttpProxyServer.bootstrap()
                .withName("Give-PlainText")
                .withPort(httpsPort)
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(true)
                .withSslEngineSource(new SimpleSslEngineSource(keyStorePath))
                .withAuthenticateSslClients(false)

                // Use a filter to deny requests other than those contains the
                // right auth token
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(HttpRequest originalRequest) {
                        return new GiveModeHttpFilters(originalRequest) {
                            @Override
                            public HttpResponse requestPre(HttpObject httpObject) {
                                if (httpObject instanceof HttpRequest) {
                                    HttpRequest req = (HttpRequest) httpObject;
                                    String authToken = req
                                            .headers()
                                            .get(GetModeHttpFilters.X_LANTERN_AUTH_TOKEN);
                                    if (!expectedAuthToken.equals(authToken)) {
                                        return mimicApache(req, httpsPort);
                                    } else {
                                        // Strip the auth token before sending
                                        // request downstream
                                        req.headers().remove(
                                                "X_LANTERN_AUTH_TOKEN");
                                    }
                                }
                                return super.requestPre(httpObject);
                            }
                        };
                    }
                })
                .start();
    }

    private void startUdt() {
        LOG.info("Starting Give proxy at UDT port {}", udtPort);
        server.clone()
                .withAddress(
                        new InetSocketAddress(server.getListenAddress()
                                .getAddress(), udtPort))
                .withTransportProtocol(TransportProtocol.UDT).start();
    }

    private HttpResponse mimicApache(HttpRequest request, int port) {
        String uri = getApacheLikeURI(request);
        if ("/".equals(uri) ||
                "/index".equals(uri) ||
                "/index.html".equals(uri)) {
            return ok(request, port);
        } else if ("/cgi-bin/php".equals(uri) || "/cgi-bin/php5".equals(uri)) {
            return internalServerError(request, port);
        } else {
            return notFound(request, port);
        }
    }

    /**
     * <p>
     * Creates a 200 response that looks like what Apache might give you for an
     * unconfigured server.
     * <p>
     * 
     * @return
     */
    private HttpResponse ok(HttpRequest request, int port) {
        LOG.debug("Returning 200 Ok response to mimic Apache: "
                + request.getUri());
        return responseFor(HttpResponseStatus.OK, OK_BODY);
    }

    /**
     * Creates a 404 response that looks like what Apache might give you for an
     * unconfigured server.
     * 
     * @return
     */
    private HttpResponse notFound(HttpRequest request, int port) {
        LOG.debug("Returning 404 Not Found response to mimic Apache: "
                + request.getUri());
        String uri = getApacheLikeURI(request);
        return responseFor(HttpResponseStatus.NOT_FOUND,
                String.format(NOT_FOUND_BODY, uri, host, port));
    }

    private HttpResponse internalServerError(HttpRequest request, int port) {
        LOG.debug("Returning 500 Internal Server Error response to mimic Apache: "
                + request.getUri());
        return responseFor(HttpResponseStatus.INTERNAL_SERVER_ERROR,
                String.format(INTERNAL_SERVER_ERROR_BODY, host, port));
    }

    /**
     * WARNING - This method is crafted to set the right headers, in the right
     * order, to mimic a specific version of Apache httpd. Change carefully!
     * 
     * @param status
     * @param body
     * @param contentLength
     * @return
     */
    private static DefaultFullHttpResponse responseFor(
            HttpResponseStatus status, String body) {
        byte[] bytes = body.getBytes(Charset.forName("UTF-8"));
        int contentLength = bytes.length;
        ByteBuf content = Unpooled.copiedBuffer(bytes);

        DefaultFullHttpResponse response = body != null ? new DefaultFullHttpResponse(
                HttpVersion.HTTP_1_1, status, content)
                : new DefaultFullHttpResponse(HttpVersion.HTTP_1_1, status);
        response.headers().add("Date", new Date())
                .add("Server", "Apache/2.2.22 (Ubuntu)");

        if (HttpResponseStatus.OK.equals(status)) {
            response.headers()
                    .add("Last-Modified", LAST_MODIFIED)
                    .add("ETag", ETAG)
                    .add("Accept-Ranges", "bytes")
                    .add(HttpHeaders.Names.CONTENT_LENGTH, contentLength)
                    .add("Vary", "Accept-Encoding")
                    .add("Connection", "close")
                    .add("Content-Type", "text/html");
        } else {
            response.headers()
                    .add("Vary", "Accept-Encoding")
                    .add(HttpHeaders.Names.CONTENT_LENGTH, contentLength)
                    .add("Connection", "close")
                    .add("Content-Type", "text/html; charset=iso-8859-1");
        }
        return response;
    }

    private static String getApacheLikeURI(HttpRequest request) {
        return request.getUri()
                // Strip duplicate leading slash like Apache
                .replaceFirst("//", "/");
    }

    private static Date LAST_MODIFIED = new Date();
    private static String ETAG = String.format("\"%1$s\"", UUID.randomUUID());

    private static String OK_BODY = "<html><body><h1>It works!</h1>\n"
            + "<p>This is the default web page for this server.</p>\n"
            + "<p>The web server software is running but no content has been added, yet.</p>\n"
            + "</body></html>\n";

    private static String NOT_FOUND_BODY = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
            + "<html><head>\n"
            + "<title>404 Not Found</title>\n"
            + "</head><body>\n"
            + "<h1>Not Found</h1>\n"
            + "<p>The requested URL %1$s was not found on this server.</p>\n"
            + "<hr>\n"
            + "<address>Apache/2.2.22 (Ubuntu) Server at %2$s Port %3$s</address>\n"
            + "</body></html>\n";

    private static String INTERNAL_SERVER_ERROR_BODY = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
            + "<html><head>\n"
            + "<title>500 Internal Server Error</title>\n"
            + "</head><body>\n"
            + "<h1>Internal Server Error</h1>\n"
            + "<p>The server encountered an internal error or\n"
            + "misconfiguration and was unable to complete\n"
            + "your request.</p>\n"
            + "<p>Please contact the server administrator,\n"
            + " webmaster@%1$s and inform them of the time the error occurred,\n"
            + "and anything you might have done that may have\n"
            + "caused the error.</p>\n"
            + "<p>More information about this error may be available\n"
            + "in the server error log.</p>\n"
            + "<hr>\n"
            + "<address>Apache/2.2.22 (Ubuntu) Server at %1$s Port %2$s</address>\n"
            + "</body></html>\n";
}
