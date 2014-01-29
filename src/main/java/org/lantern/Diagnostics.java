/**
 * This is obsolete.
 *
 * It needs to be ported to use new fallbacks (auth token, certs), and
 * probably the S3 config scheme.
 */
package org.lantern;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import javax.swing.BorderFactory;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.SwingConstants;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.common.io.Files;
import com.google.inject.Injector;

/**
 * End-to-end proxying test to make sure we're able to proxy access to
 * different sites.
 */
public class Diagnostics {

    private static final Logger log = LoggerFactory.getLogger(Diagnostics.class);
    private static JLabel output;
    
    private static final StringBuilder text = new StringBuilder();
    
    private static final Object PROXY_LOCK = new Object();
    
    private static final File certsFile = new File("src/test/resources/cacerts");

    public static void main(final String[] clArgs) {
        //System.setProperty("javax.net.debug", "ssl");
        //Launcher.main(false, args);
        final HttpClient client = new DefaultHttpClient();
        final HttpGet get = new HttpGet("https://www.github.com");
        try {
            final HttpResponse response = client.execute(get);
            final int status = response.getStatusLine().getStatusCode();
            System.err.println("Status: "+status);
            final HttpEntity entity = response.getEntity();
            final String raw = IOUtils.toString(entity.getContent());
            //System.out.println(raw);
        } catch (ClientProtocolException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        final Diagnostics diagnostics = new Diagnostics();
        Events.register(diagnostics);
    }

    private String fallbackServerHost;
    private int fallbackServerPort;
    
    private Diagnostics() {
        System.err.println("Trust store: "+System.getProperty("javax.net.ssl.trustStore"));
        text.append("<html>");
        final JFrame frame = new JFrame("Lantern Diagnostics...");
        frame.addWindowListener(new java.awt.event.WindowAdapter() {
            @Override
            public void windowClosing(java.awt.event.WindowEvent windowEvent) {
                if (JOptionPane.showConfirmDialog(frame, 
                    "Are you sure you want to close Lantern Diagnostic tests?", "Quit?", 
                    JOptionPane.YES_NO_OPTION,
                    JOptionPane.QUESTION_MESSAGE) == JOptionPane.YES_OPTION){
                    log.info("Quitting Lantern from diagnostics pane");
                    System.exit(0);
                }
            }
        });
        
        final JPanel contentPane = new JPanel();
        contentPane.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
        contentPane.setLayout(new BorderLayout());
        output = new JLabel("Testing") {
            private static final long serialVersionUID = -4035525678544713613L;
            
            @Override
            public Dimension getPreferredSize() {
                return new Dimension(800, 600);
            }
            @Override
            public Dimension getMinimumSize() {
                return new Dimension(800, 600);
            }
            @Override
            public Dimension getMaximumSize() {
                return new Dimension(800, 600);
            }
        };
        output.setVerticalAlignment(SwingConstants.TOP);
        output.setHorizontalAlignment(SwingConstants.LEFT);
        output.setForeground(Color.GREEN);
        
        contentPane.setBackground(Color.BLACK);
        contentPane.add(output, BorderLayout.CENTER);
        
        frame.setContentPane(contentPane);
        frame.pack();
        frame.setLocationRelativeTo(null);
        frame.setVisible(true);

        output("Starting diagnostics...");
        try {
            output("Deleting Lantern configuration directory...");
            FileUtils.deleteDirectory(LanternClientConstants.CONFIG_DIR);
        } catch (IOException e1) {
            output("Could not delete Lantern configuration directory?");
        }
        final String refresh = LanternUtils.getRefreshToken();
        final String access = LanternUtils.getAccessToken();
        if (org.apache.commons.lang3.StringUtils.isBlank(refresh)) {
            output("NO REFRESH TOKEN!! CANNOT TEST. CLOSE WINDOW TO QUIT.");
        } else if (org.apache.commons.lang3.StringUtils.isBlank(access)) {
            output("NO ACCESS TOKEN!! CANNOT TEST. CLOSE WINDOW TO QUIT.");
        } else {
            runDiagnostics(refresh, access);
        }
    }

    private void runDiagnostics(final String refresh, final String access) {

        final String[] args = new String[]{"--disable-ui", "--force-get", 
                "--refresh-tok", refresh, 
                "--access-tok", access, 
                "--disable-trusted-peers", "--disable-anon-peers"};

        final LanternModule lm = new LanternModule(args);

        output("Creating lantern module...");
        final Launcher launcher = new Launcher(lm);
        launcher.configureDefaultLogger();
        
        output("Running Lantern. This will include logging in to Google Talk " +
            "and may take awhile...");
        launcher.launch();
        launcher.model.setSetupComplete(true);
        output("Setup complete...");
        output("Created Lantern...");
        
        if (!certsFile.isFile()) {
            final File certsFile2 = new File("cacerts");
            if (!certsFile2.isFile()) {
                output("Could not find cacerts?");
                throw new IllegalStateException("COULD NOT FIND CACERTS!!");
            }
        }
        
        testProxy();
        
        // We set this back to the global trust store because in this case 
        // we're testing a bunch of sites, not just the ones lantern accesses
        // internally.
        //System.setProperty("javax.net.ssl.trustStore", 
                //certsFile.getAbsolutePath());
        
        //System.setProperty("javax.net.ssl.trustStore", null);
        
        System.err.println("Trust store: "+System.getProperty("javax.net.ssl.trustStore"));
        output("Checking localhost server...");
        LanternUtils.waitForServer(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);

        output("Connected to server....");
        final Collection<String> censored = Arrays.asList(
            //"www.getlantern.org",
            //"github.com",
            "facebook.com",
                "yahoo.com"
            //"appledaily.com.tw", 
            //"orkut.com", 
            //"voanews.com",
            //"balatarin.com",
            //"igfw.net"
                );
        
        //final SSLSocketFactory socketFactory = 
            //new SSLSocketFactory(
              //  (javax.net.ssl.SSLSocketFactory) javax.net.ssl.SSLSocketFactory.getDefault(),
                //new BrowserCompatHostnameVerifier());
        
        final Injector injector = launcher.getInjector();
        //final HttpClientFactory clientFactory = 
            //injector.getInstance(HttpClientFactory.class);
        final ProxyTracker pt = injector.getInstance(DefaultProxyTracker.class);
        synchronized (PROXY_LOCK) {
            if (!pt.hasProxy()) {
                try {
                    PROXY_LOCK.wait(20000);
                } catch (InterruptedException e) {
                }
            }
        }
        if (!pt.hasProxy()) {
            output("Still no proxy!! Exiting");
            log.info("Still no proxy, exiting from Diagnostics dialog");
            System.exit(0);
        }
        
        //final Scheme sch = new Scheme("https", 443, socketFactory);
        //client.getConnectionManager().getSchemeRegistry().register(sch);
        
        System.setProperty("javax.net.ssl.trustStore", certsFile.getAbsolutePath());
        final Collection<String> successful = new HashSet<String>();
        final Collection<String> failed = new HashSet<String>();
        for (final String site : censored) {
            // Just a blank line...
            final long start = System.currentTimeMillis();
            output("");
            output("Testing access to site: " + site);
            try {
                final boolean succeeded = testWhitelistedSite(site,
                    LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
                final long time = System.currentTimeMillis() - start;
                if (succeeded) {
                    output("Successfully proxied access to "+site+" in "+time/1000+" seconds.");
                    successful.add(site);
                } else {
                    failed.add(site);
                    output("Failed to proxy access to "+site+" in "+time/1000+" seconds.");
                }
            } catch (final Exception e) {
                output("Failed to proxy access to "+site);
                failed.add(site);
            }
            log.debug("FINISHED TESTING SITE: {}", site);
        }
        
        output("");
        output("ALL TESTS COMPLETE!");
        output("");
        output("CLOSE THE WINDOW TO QUIT.");
    }

    private void testProxy() {
        output("Testing proxy access...");
        parseFallbackProxy();
        output("Testing proxy address "+this.fallbackServerHost+" and port "+
                this.fallbackServerPort);
        
        Socket sock = null;
        try {
            sock = new Socket();
            sock.connect(new InetSocketAddress(fallbackServerHost, fallbackServerPort), 40000);
            output("Connected to proxy!!!");
        } catch (IOException e) {
            output("Failed to connect!!\n"+ThreadUtils.dumpStack(e));
            IOUtils.closeQuietly(sock);
            return;
        } finally {
            //IOUtils.closeQuietly(sock);
        }
        
        final SSLSocketFactory sslFactory =
                (SSLSocketFactory)SSLSocketFactory.getDefault();
        
        SSLSocket ssl = null;
        try {
            ssl = (SSLSocket) sslFactory.createSocket(sock, 
                    sock.getInetAddress().getHostAddress(), sock.getPort(), false);
            output("Starting SSL handshake...");
            ssl.startHandshake();
            output("Completed SSL handshake...");
        } catch (final IOException e) {
            output("Could not upgrade socket to SSL!!\n"+ThreadUtils.dumpStack(e));
            return;
        } finally {
            
        }
        
    }
    
    private void parseFallbackProxy() {
        final File file = 
            new File(LanternClientConstants.CONFIG_DIR, "fallback.json");
        if (!file.isFile()) {
            try {
                copyFallback();
            } catch (final IOException e) {
                log.error("Could not copy fallback?", e);
            }
        }
        if (!file.isFile()) {
            log.error("No fallback proxy to load!");
            return;
        }

        InputStream is = null;
        try {
            is = new FileInputStream(file);
            final String proxy = IOUtils.toString(is);
            final FallbackProxy fp = 
                    JsonUtils.OBJECT_MAPPER.readValue(proxy, FallbackProxy.class);
            
            fallbackServerHost = fp.getIp();
            fallbackServerPort = fp.getPort();
            log.debug("Set fallback proxy to {}", fallbackServerHost);
        } catch (final IOException e) {
            log.error("Could not load fallback", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    
    private void copyFallback() throws IOException {
        log.debug("Copying fallback file");
        final File from;
        
        final File home = 
            new File(new File(SystemUtils.USER_HOME), "fallback.json");
        if (home.isFile()) {
            from = home;
        } else {
            log.debug("No fallback proxy found in home - checking cur...");
            final File curDir = new File("fallback.json");
            if (curDir.isFile()) {
                from = curDir;
            } else {
                log.warn("Still could not find fallback proxy!");
                return;
            }
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, from.getName());
        if (!par.isDirectory() && !par.mkdirs()) {
            throw new IOException("Could not make config dir?");
        }
        Files.copy(from, to);
    }

    private boolean testWhitelistedSite(final String url, final int proxyPort) {
        
        System.err.println("Trust store: "+System.getProperty("javax.net.ssl.trustStore"));
        
        final DefaultHttpClient client = new DefaultHttpClient();
  
        final HttpGet get = new HttpGet("http://"+url);
        
        //final HttpHost proxy = new HttpHost(this.fallbackServerHost, 
         //       this.fallbackServerPort, "https");
        //client.getConnectionManager().getSchemeRegistry().register(sch);
        //client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
        
        client.setHttpRequestRetryHandler(new DefaultHttpRequestRetryHandler(2,true));
        
        // Some sites require more standard headers to be present.
        get.setHeader("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:15.0) Gecko/20100101 Firefox/15.0");
        get.setHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        get.setHeader("Accept-Language", "en-us,en;q=0.5");
        get.setHeader("Accept-Encoding", "gzip, deflate");
        
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 
            30000);
        // Timeout when server does not send data.
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 60000);
        client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, 
            new HttpHost("localhost", proxyPort));
        
        System.setProperty("javax.net.ssl.trustStore", 
                certsFile.getAbsolutePath());
        final HttpResponse response;
        try {
            response = client.execute(get);
            final int code = response.getStatusLine().getStatusCode();
            if (200 !=  code) {
                output("Received unexpected status code: "+code);
                return false;
            }
            output("Received response from "+url);
            log.debug("Consuming entity");
            final HttpEntity entity = response.getEntity();
            final String raw = IOUtils.toString(entity.getContent());
            //log.debug("Raw response: "+raw);
            
            // The response body can actually be pretty small -- consider 
            // responses like 
            // <meta http-equiv="refresh" content="0;url=index.html">
            if (raw.length() <= 40) {
                output("Received unexpected response length: " + raw.length() +
                    ". Response was "+raw);
                return false;
            }
            EntityUtils.consume(entity);
            return true;
        } catch (final ClientProtocolException e) {
            output("Protocol error connecting to "+url, e);
            return false;
        } catch (final IOException e) {
            output("IO error connecting to "+url, e);
            return false;
        } finally {
            get.reset();
        }
    }
    

    private static void output(final String str) {
        output(str, null);
    }

    private static void output(final String str, final Exception e) {
        if (e != null) {
            log.info(str, e);
        } else {
            log.info(str);
        }
        text.append("<div>");
        text.append(str);
        text.append("</div>");
        final String full = text.toString()+"</html>";
        output.setText(full);
    }
    
    @Subscribe
    public synchronized void onProxyConnectionEvent(
        final ProxyConnectionEvent pce) {
        final ConnectivityStatus stat = pce.getConnectivityStatus();
        switch (stat) {
        case CONNECTED:
            output("Got connected event");
            synchronized (PROXY_LOCK) {
                PROXY_LOCK.notifyAll();
            }
            break;
        case CONNECTING:
            output("Got connecting event");
            break;
        case DISCONNECTED:
            output("Got disconnected event");
            break;
        default:
            break;
        
        }
    }
}
