package org.lantern;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;

import javax.swing.BorderFactory;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.SwingConstants;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Module;

/**
 * End-to-end proxying test to make sure we're able to proxy access to
 * different sites.
 */
public class Diagnostics {

    private static final Logger log = LoggerFactory.getLogger(Diagnostics.class);
    private static JLabel output;
    
    private static final StringBuilder text = new StringBuilder();

    public static void main(final String[] clArgs) {
        //System.setProperty("javax.net.debug", "ssl");
        //Launcher.main(false, args);
        
        text.append("<html>");
        final JFrame frame = new JFrame("Lantern Diagnostics...");
        frame.addWindowListener(new java.awt.event.WindowAdapter() {
            @Override
            public void windowClosing(java.awt.event.WindowEvent windowEvent) {
                if (JOptionPane.showConfirmDialog(frame, 
                    "Are you sure you want to close Lantern Diagnostic tests?", "Quit?", 
                    JOptionPane.YES_NO_OPTION,
                    JOptionPane.QUESTION_MESSAGE) == JOptionPane.YES_OPTION){
                    System.exit(0);
                }
            }
        });
        
        final JPanel contentPane = new JPanel();
        contentPane.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
        contentPane.setLayout(new BorderLayout());
        output = new JLabel("Testing") {
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

    private static void runDiagnostics(final String refresh, final String access) {

        final String[] args = new String[]{"--disable-ui", "--force-get", 
                "--refresh-tok", refresh, 
                "--access-tok", access, 
                "--disable-trusted-peers", "--disable-anon-peers"};

        final Module lm = new LanternModule();

        output("Creating lantern module...");
        final Launcher launcher = new Launcher(lm, args);
        launcher.configureDefaultLogger();
        
        output("Running Lantern. This will include logging in to Google Talk and may take awhile...");
        final Runnable starter = new Runnable() {

            @Override
            public void run() {
                launcher.run();
                launcher.model.setSetupComplete(true);
                synchronized (Diagnostics.class) {
                    Diagnostics.class.notify();
                }
            }
        };
        final Thread t = new Thread(starter, "Diagnostics-Startup");
        t.start();

        synchronized (Diagnostics.class) {
            try {
                Diagnostics.class.wait(40000);
            } catch (InterruptedException e) {
            }
        }
        output("Created Lantern...");
        
        final File certsFile = new File("src/test/resources/cacerts");
        if (!certsFile.isFile()) {
            output("Could not find cacerts?");
            throw new IllegalStateException("COULD NOT FIND CACERTS!!");
        }
        
        // We set this back to the global trust store because in this case 
        // we're testing a bunch of sites, not just the ones lantern accesses
        // internally.
        System.setProperty("javax.net.ssl.trustStore", certsFile.getAbsolutePath());
        
        LanternUtils.waitForServer(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);

        output("Connected to server....");
        final Collection<String> censored = Arrays.asList(//"exceptional.io");
            //"www.getlantern.org",
            "github.com",
            "facebook.com", 
            "appledaily.com.tw", 
            "orkut.com", 
            "voanews.com",
            "balatarin.com",
            "igfw.net"
                );
        
        //final SSLSocketFactory socketFactory = 
            //new SSLSocketFactory(
              //  (javax.net.ssl.SSLSocketFactory) javax.net.ssl.SSLSocketFactory.getDefault(),
                //new BrowserCompatHostnameVerifier());
        final HttpClient client = new DefaultHttpClient();
        //final Scheme sch = new Scheme("https", 443, socketFactory);
        //client.getConnectionManager().getSchemeRegistry().register(sch);
        
        final Collection<String> successful = new HashSet<String>();
        final Collection<String> failed = new HashSet<String>();
        for (final String site : censored) {
            // Just a blank line...
            final long start = System.currentTimeMillis();
            output("");
            output("Testing access to site: " + site);
            try {
                final boolean succeeded = testWhitelistedSite(site, client,
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

    private static boolean testWhitelistedSite(final String url,
        final HttpClient client, final int proxyPort) {
        final HttpGet get = new HttpGet("http://"+url);
        
        // Some sites require more standard headers to be present.
        get.setHeader("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:15.0) Gecko/20100101 Firefox/15.0");
        get.setHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        get.setHeader("Accept-Language", "en-us,en;q=0.5");
        get.setHeader("Accept-Encoding", "gzip, deflate");
        
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 
            6000);
        // Timeout when server does not send data.
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 30000);
        client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, 
            new HttpHost("localhost", proxyPort));
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
}
