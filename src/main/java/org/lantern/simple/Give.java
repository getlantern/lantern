package org.lantern.simple;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.DefaultFullHttpResponse;
import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;
import io.netty.handler.codec.http.HttpResponseStatus;
import io.netty.handler.codec.http.HttpVersion;

import java.nio.charset.Charset;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import org.apache.commons.cli.Option;
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
 * all Get proxies. Mostly for experimentation purposes.
 * </p>
 * 
 * <p>
 * Run like this:
 * </p>
 * 
 * <pre>
 * ./launch org.lantern.simple.Give -host 127.0.0.1 -http 46000 -https 46001 -udt 46002 -keystore ../too-many-secrets/littleproxy_keystore.jks -authtoken '534#^#$523590)'
 * </pre>
 * 
 * <pre>
 * usage: ./launch org.lantern.simple.Give [options]
 *  -authtoken <arg>   Auth token that this proxy requires from its clients.
 *                     Defaults to '534#^#$523590)'.
 *  -host <arg>        (Required) The proxy's public hostname or ip address
 *  -http <arg>        HTTP listen port.  Defaults to 80.
 *  -https <arg>       HTTPS listen port.  Defaults to 443.
 *  -keystore <arg>    Path to keystore containing proxy's cert.  Defaults to
 *                     ../too-many-secrets/littleproxy_keystore.jks
 *  -udt <arg>         UDT listen port.  Defaults to 9090.
 * </pre>
 */
public class Give extends CliProgram {
    private static final Logger LOG = LoggerFactory.getLogger(Give.class);
    // Http Methods known to Apache
    private static final Set<HttpMethod> KNOWN_METHODS = new HashSet<HttpMethod>();
    private static final Set<HttpMethod> ALLOWED_METHODS = new HashSet<HttpMethod>();
    private static final Set<String> KNOWN_URIS = new HashSet<String>();
    private static final Set<String> BAD_URIS = new HashSet<String>();
    private static final String OPT_HOST = "host";
    private static final String OPT_HTTP_PORT = "http";
    private static final String OPT_HTTPS_PORT = "https";
    private static final String OPT_UDT_PORT = "udt";
    private static final String OPT_KEYSTORE = "keystore";
    private static final String OPT_AUTHTOKEN = "authtoken";

    private String host;
    private int httpsPort;
    private int httpPort;
    private int udtPort;
    private String keyStorePath;
    private String expectedAuthToken;
    private HttpProxyServer server;

    public static void main(String[] args) throws Exception {
        initializeObfuscation();
        new Give(args).start();
    }

    public Give(String[] args) {
        super(args);
        this.host = cmd.getOptionValue(OPT_HOST);
        this.httpPort = Integer.parseInt(cmd
                .getOptionValue(OPT_HTTP_PORT, "80"));
        this.httpsPort = Integer.parseInt(cmd.getOptionValue(OPT_HTTPS_PORT,
                "443"));
        this.udtPort = Integer.parseInt(cmd.getOptionValue(OPT_UDT_PORT,
                "9090"));
        this.keyStorePath = cmd.getOptionValue(OPT_KEYSTORE,
                "../too-many-secrets/littleproxy_keystore.jks");
        this.expectedAuthToken = cmd.getOptionValue(OPT_AUTHTOKEN,
                "534#^#$523590)");
    }

    public void start() {
        System.out.println(String
                .format("Starting Give proxy with the following settings ...\n"
                        +
                        "Host: %1$s\n" +
                        "HTTP port: %2$s\n" +
                        "HTTPS port: %3$s\n" +
                        "UDT port: %4$s\n" +
                        "Keystore path: %5$s\n" +
                        "Auth token: %6$s\n",
                        host,
                        httpPort,
                        httpsPort,
                        udtPort,
                        keyStorePath,
                        expectedAuthToken));
        startTcp();
        startUdt();
    }

    protected void initializeCliOptions() {
        //@formatter:off
        addOption(new Option(OPT_HOST, true, "(Required) The proxy's public hostname or ip address"), true);
        addOption(new Option(OPT_HTTP_PORT, true, "HTTP listen port.  Defaults to 80."), false);
        addOption(new Option(OPT_HTTPS_PORT, true, "HTTPS listen port.  Defaults to 443."), false);
        addOption(new Option(OPT_UDT_PORT, true, "UDT listen port.  Defaults to 9090."), false);
        addOption(new Option(OPT_KEYSTORE, true, "Path to keystore containing proxy's cert.  Defaults to ../too-many-secrets/littleproxy_keystore.jks"), false);
        addOption(new Option(OPT_AUTHTOKEN, true, "Auth token that this proxy requires from its clients.  Defaults to '534#^#$523590)'."), false);
        //@formatter:on
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
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest, ctx,
                                host,
                                httpPort, TransportProtocol.TCP,
                                expectedAuthToken);
                    }
                })
                .start();

        LOG.info(
                "Starting TLS Give proxy at TCP port {}", httpsPort);
        server = DefaultHttpProxyServer.bootstrap()
                .withName("Give-Encrypted")
                .withPort(httpsPort)
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(true)
                .withSslEngineSource(new SimpleSslEngineSource(keyStorePath))
                .withAuthenticateSslClients(false)

                // Use a filter to deny requests other than those contains the
                // right auth token
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest, ctx,
                                host,
                                httpsPort, TransportProtocol.TCP,
                                expectedAuthToken);
                    }
                })
                .start();
    }

    private void startUdt() {
        LOG.info("Starting Give proxy at UDT port {}", udtPort);
        server.clone()
                .withName("Give-UDT")
                .withPort(udtPort)
                .withTransportProtocol(TransportProtocol.UDT)

                // Use a filter to deny requests other than those contains the
                // right auth token
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest, ctx,
                                host,
                                udtPort, TransportProtocol.UDT,
                                expectedAuthToken);
                    }
                })
                .start();
    }

    /**
     * WARNING - this method, including logic, headers and so on is carefully
     * crafted to mimic a mostly unconfigured Apache 2.2.22 running on Ubuntu
     * 12.04.
     * 
     * @param request
     * @param port
     * @return
     */
    private HttpResponse mimicApache(HttpRequest request, int port) {
        String uri = getApacheLikeURI(request);
        if (uri.endsWith("/")) {
            return forbidden(request, port);
        } else if (BAD_URIS.contains(uri)) {
            return internalServerError(request, port);
        } else if (uri.toLowerCase().startsWith("/cgi-bin/")) {
            return notFound(request, port);
        } else if (HttpMethod.OPTIONS.equals(request.getMethod())) {
            return optionsResponse(request, port);
        } else if (!KNOWN_METHODS.contains(request.getMethod())) {
            return methodNotImplemented(request, port);
        } else if (!ALLOWED_METHODS.contains(request.getMethod())) {
            return methodNotAllowed(request, port);
        } else if (KNOWN_URIS.contains(uri)) {
            return ok(request, port);
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
        DefaultFullHttpResponse response = responseFor(HttpResponseStatus.OK,
                OK_BODY);
        response.headers()
                .add("Last-Modified", LAST_MODIFIED)
                .add("ETag", ETAG)
                .add("Accept-Ranges", "bytes")
                .add(HttpHeaders.Names.CONTENT_LENGTH,
                        response.content().capacity())
                .add("Vary", "Accept-Encoding")
                .add("Connection", "close")
                .add("Content-Type", "text/html");
        return response;
    }

    /**
     * Generate a response to an OPTIONS request that looks like Apache's
     * response.
     * 
     * @param request
     * @param port
     * @return
     */
    private HttpResponse optionsResponse(HttpRequest request, int port) {
        DefaultFullHttpResponse response = responseFor(HttpResponseStatus.OK);
        response.headers()
                .add("Allow", "GET,HEAD,POST,OPTIONS")
                .add("Vary", "Accept-Encoding")
                .add("Content-Length", 0)
                .add("Content-Type", "text/html");
        return response;
    }

    private HttpResponse forbidden(HttpRequest request, int port) {
        String uri = getApacheLikeURI(request);
        DefaultFullHttpResponse response = responseFor(
                HttpResponseStatus.FORBIDDEN,
                String.format(FORBIDDEN_BODY, uri, host, port));
        response.headers()
                .add("Vary", "Accept-Encoding")
                .add("Content-Length", response.content().capacity())
                .add("Content-Type", "text/html; charset=iso-8859-1");
        return response;
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
        DefaultFullHttpResponse response = responseFor(
                HttpResponseStatus.NOT_FOUND,
                String.format(NOT_FOUND_BODY, uri, host, port));
        response.headers()
                .add("Vary", "Accept-Encoding")
                .add(HttpHeaders.Names.CONTENT_LENGTH,
                        response.content().capacity())
                .add("Connection", "close")
                .add("Content-Type", "text/html; charset=iso-8859-1");
        return response;
    }

    /**
     * Creates a 500 response that looks somewhat
     * 
     * @param request
     * @param port
     * @return
     */
    private HttpResponse internalServerError(HttpRequest request, int port) {
        LOG.debug("Returning 500 Internal Server Error response to mimic Apache: "
                + request.getUri());
        DefaultFullHttpResponse response = responseFor(
                HttpResponseStatus.INTERNAL_SERVER_ERROR,
                String.format(INTERNAL_SERVER_ERROR_BODY, host, port));
        response.headers()
                .add("Vary", "Accept-Encoding")
                .add(HttpHeaders.Names.CONTENT_LENGTH,
                        response.content().capacity())
                .add("Connection", "close")
                .add("Content-Type", "text/html; charset=iso-8859-1");
        return response;
    }

    private HttpResponse methodNotAllowed(HttpRequest request, int port) {
        LOG.debug("Returning 405 Method Not Allowed response to mimic Apache: "
                + request.getUri());
        String uri = getApacheLikeURI(request);
        DefaultFullHttpResponse response = responseFor(
                HttpResponseStatus.METHOD_NOT_ALLOWED,
                String.format(METHOD_NOT_ALLOWED_BODY,
                        request.getMethod().name(),
                        uri,
                        host,
                        port));
        response.headers()
                .add("Allow", "GET,HEAD,POST,OPTIONS")
                .add("Vary", "Accept-Encoding")
                .add("Content-Length", response.content().capacity())
                .add("Content-Type", "text/html; charset=iso-8859-1");
        return response;
    }

    private HttpResponse methodNotImplemented(HttpRequest request, int port) {
        LOG.debug("Returning 501 Method Not Implemented response to mimic Apache: "
                + request.getUri());
        String uri = getApacheLikeURI(request);
        DefaultFullHttpResponse response = responseFor(
                HttpResponseStatus.NOT_IMPLEMENTED,
                String.format(NOT_IMPLEMENTED_BODY,
                        request.getMethod().name(),
                        uri,
                        host,
                        port));
        response.headers()
                .add("Allow", "GET,HEAD,POST,OPTIONS")
                .add("Vary", "Accept-Encoding")
                .add("Content-Length", response.content().capacity())
                .add("Connection", "close")
                .add("Content-Type", "text/html; charset=iso-8859-1");
        return response;
    }

    private static DefaultFullHttpResponse responseFor(
            HttpResponseStatus status) {
        return responseFor(status, null);
    }

    /**
     * @param status
     * @param body
     * @param contentLength
     * @return
     */
    private static DefaultFullHttpResponse responseFor(
            HttpResponseStatus status, String body) {
        DefaultFullHttpResponse response;
        if (body != null) {
            byte[] bytes = body.getBytes(Charset.forName("UTF-8"));
            ByteBuf content = Unpooled.copiedBuffer(bytes);
            response = new DefaultFullHttpResponse(
                    HttpVersion.HTTP_1_1, status, content);
        } else {
            response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1, status);
        }

        response.headers()
                .add("Date", new Date())
                // This mimics setting 'ServerTokens Prod'
                .add("Server", "Apache");
        return response;
    }

    private static String getApacheLikeURI(HttpRequest request) {
        String uri = request.getUri()
                // Strip duplicate leading slash like Apache
                .replaceFirst("//", "/");
        if ("/".equals(uri)) {
            uri = "/index.html";
        }
        return uri;
    }

    private static Date LAST_MODIFIED = new Date();
    private static String ETAG = String.format("\"%1$s\"", UUID.randomUUID());

    private static String OK_BODY = "<html><body><h1>It works!</h1>\n"
            + "<p>This is the default web page for this server.</p>\n"
            + "<p>The web server software is running but no content has been added, yet.</p>\n"
            + "</body></html>\n";

    private static String FORBIDDEN_BODY = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
            + "<html><head>\n"
            + "<title>403 Forbidden</title>\n"
            + "</head><body>\n"
            + "<h1>Forbidden</h1>\n"
            + "<p>You don't have permission to access %1$s\n"
            + "on this server.</p>\n"
            + "<hr>\n"
            + "<address>Apache Server at %2$s Port %3$s</address>\n"
            + "</body></html>\n";

    private static String NOT_FOUND_BODY = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
            + "<html><head>\n"
            + "<title>404 Not Found</title>\n"
            + "</head><body>\n"
            + "<h1>Not Found</h1>\n"
            + "<p>The requested URL %1$s was not found on this server.</p>\n"
            + "<hr>\n"
            + "<address>Apache Server at %2$s Port %3$s</address>\n"
            + "</body></html>\n";

    private static String METHOD_NOT_ALLOWED_BODY = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
            + "<html><head>\n"
            + "<title>405 Method Not Allowed</title>\n"
            + "</head><body>\n"
            + "<h1>Method Not Allowed</h1>\n"
            + "<p>The requested method %1$s is not allowed for the URL %2$s.</p>\n"
            + "<hr>\n"
            + "<address>Apache Server at %3$s Port %4$s</address>\n"
            + "</body></html>\n";

    private static String NOT_IMPLEMENTED_BODY = "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
            + "<html><head>\n"
            + "<title>501 Method Not Implemented</title>\n"
            + "</head><body>\n"
            + "<h1>Method Not Implemented</h1>\n"
            + "<p>%1$s to %2$s not supported.<br />\n"
            + "</p>\n"
            + "<hr>\n"
            + "<address>Apache Server at %3$s Port %4$s</address>\n"
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
            + "<address>Apache Server at %1$s Port %2$s</address>\n"
            + "</body></html>\n";

    private static void initializeObfuscation() {
        KNOWN_METHODS.add(new HttpMethod("BASELINE-CONTROL"));
        KNOWN_METHODS.add(new HttpMethod("CHECKIN"));
        KNOWN_METHODS.add(new HttpMethod("CHECKOUT"));
        KNOWN_METHODS.add(new HttpMethod("CONNECT"));
        KNOWN_METHODS.add(new HttpMethod("COPY"));
        KNOWN_METHODS.add(new HttpMethod("DELETE"));
        KNOWN_METHODS.add(new HttpMethod("GET"));
        KNOWN_METHODS.add(new HttpMethod("HEAD"));
        KNOWN_METHODS.add(new HttpMethod("LABEL"));
        KNOWN_METHODS.add(new HttpMethod("LOCK"));
        KNOWN_METHODS.add(new HttpMethod("MERGE"));
        KNOWN_METHODS.add(new HttpMethod("MKACTIVITY"));
        KNOWN_METHODS.add(new HttpMethod("MKCOL"));
        KNOWN_METHODS.add(new HttpMethod("MKWORKSPACE"));
        KNOWN_METHODS.add(new HttpMethod("MOVE"));
        KNOWN_METHODS.add(new HttpMethod("OPTIONS"));
        KNOWN_METHODS.add(new HttpMethod("PATCH"));
        KNOWN_METHODS.add(new HttpMethod("POLL"));
        KNOWN_METHODS.add(new HttpMethod("POST"));
        KNOWN_METHODS.add(new HttpMethod("PROPFIND"));
        KNOWN_METHODS.add(new HttpMethod("PROPPATCH"));
        KNOWN_METHODS.add(new HttpMethod("PUT"));
        KNOWN_METHODS.add(new HttpMethod("REPORT"));
        KNOWN_METHODS.add(new HttpMethod("TRACE"));
        KNOWN_METHODS.add(new HttpMethod("UNCHECKOUT"));
        KNOWN_METHODS.add(new HttpMethod("UNLOCK"));
        KNOWN_METHODS.add(new HttpMethod("UPDATE"));
        KNOWN_METHODS.add(new HttpMethod("VERSION-CONTROL"));

        ALLOWED_METHODS.add(HttpMethod.GET);
        ALLOWED_METHODS.add(HttpMethod.HEAD);
        ALLOWED_METHODS.add(HttpMethod.POST);
        ALLOWED_METHODS.add(HttpMethod.OPTIONS);

        BAD_URIS.add("/cgi-bin/php");
        BAD_URIS.add("/cgi-bin/php5");

        KNOWN_URIS.add("/");
        KNOWN_URIS.add("/index");
        KNOWN_URIS.add("/index.html");
    }

}
