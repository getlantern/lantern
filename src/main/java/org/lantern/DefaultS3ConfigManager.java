package org.lantern;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.security.SecureRandom;
import java.util.Collection;
import java.util.Set;
import java.util.HashSet;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.HttpResponse;
import org.codehaus.jackson.map.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.google.common.io.Files;
import com.google.inject.Singleton;

import org.lantern.util.HttpClientFactory;


@Singleton
public class DefaultS3ConfigManager implements S3ConfigManager {

    private static final Logger log
        = LoggerFactory.getLogger(S3ConfigManager.class);

    private static final String URL_FILENAME = "configurl.txt";

    private String url;

    private S3Config config;

    private Set<Runnable> updateCallbacks = new HashSet<Runnable>();

    private SecureRandom random = new SecureRandom();

    public DefaultS3ConfigManager() {}

    public Collection<FallbackProxy> getFallbackProxies() {
        assureConfigInited();
        if (config == null) {
            return new HashSet<FallbackProxy>();
        }
        return config.getFallbacks();
    }

    public void registerUpdateCallback(Runnable r) {
        updateCallbacks.add(r);
    }

    private void assureConfigInited() {
        if (config == null) {
            config = fetchConfig();
            scheduleConfigRecheck();
        }
    }

    private void scheduleConfigRecheck() {
        assureConfigInited();
        final double minutesToSleep
            // Temporary network problems?  Let's retry in a few seconds.
            = (config == null) ? 0.2
                               : lerp(config.getMinpoll(),
                                      config.getMaxpoll(),
                                      random.nextDouble());

        Thread t = new Thread(new Runnable() {
            public void run() {
                try {
                    Thread.sleep((long)(minutesToSleep * 60000));
                    recheckConfig();
                    scheduleConfigRecheck();
                } catch (InterruptedException e) {}
            }
        });
        t.setName("S3Config-Recheck");
        t.setDaemon(true);
        t.start();
    }

    private void recheckConfig() {
        log.debug("Rechecking configuration");
        S3Config newConfig = fetchConfig();
        if (newConfig == null) {
            log.error("Couldn't get new config.");
            return;
        }
        boolean changed;
        if (config == null) {
            log.warn("Rechecking config with no old one.");
            changed = true;
        } else {
            changed = (newConfig.getSerial_no() != config.getSerial_no());
        }
        config = newConfig;
        if (changed) {
            log.info("Configuration changed! Reapplying...");
            for (Runnable r : updateCallbacks) {
                try {
                    r.run();
                } catch (Exception e) {
                    log.error("Exception running config update callback:", e);
                }
            }
        } else {
            log.debug("Configuration unchanged.");
        }
    }

    /** Linear interpolation. */
    private double lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }

    private void assureUrlInited() {
        if (url == null) {
            try {
                copyUrlFile();
            } catch (final IOException e) {
                log.warn("Couldn't copy config URL file?", e);
            }
            url = readUrl();
        }
    }

    private static String readUrl() {
        File file = new File(LanternClientConstants.CONFIG_DIR,
                             URL_FILENAME);
        if (file.isFile()) {
            try {
                String folder = FileUtils.readFileToString(file, "UTF-8");
                return LanternConstants.S3_CONFIG_BASE_URL
                    + folder
                    + "/config.json";
            } catch (IOException e) {
                log.error("Couldn't read config URL file?", e);
            }
        } else {
            log.error("No config URL file?");
        }
        return null;
    }

    private S3Config fetchConfig() {
        assureUrlInited();
        if (url == null) {
            log.error("URL initialization failed.");
            return null;
        }
        HttpClient client = HttpClientFactory.newDirectClient();
        HttpGet get = new HttpGet(url);
        ObjectMapper om = new ObjectMapper();
        InputStream is = null;
        try {
            HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            String cfgStr = IOUtils.toString(is);
            S3Config cfg = om.readValue(cfgStr, S3Config.class);
            log.debug("Serial number: " + cfg.getSerial_no());
            log.debug("Controller: " + cfg.getController());
            log.debug("Minimum poll time: " + cfg.getMinpoll());
            log.debug("Maximum poll time: " + cfg.getMaxpoll());
            for (FallbackProxy fp : cfg.getFallbacks()) {
                log.debug("Proxy: " + fp);
            }
            return cfg;
        } catch (Exception e) {
            log.error("Couldn't fetch config: " + e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        return null;
    }

    private static void copyUrlFile() throws IOException {
        log.debug("Copying config URL file");
        final File from;

        final File cur = new File(new File(SystemUtils.USER_HOME),
                                  URL_FILENAME);
        if (cur.isFile()) {
            from = cur;
        } else {
            log.debug("No config URL file found in home"
                      + " - checking runtime user.dir...");
            final File home = new File(new File(SystemUtils.USER_DIR),
                                       URL_FILENAME);
            if (home.isFile()) {
                from = home;
            } else {
                log.warn("Still could not find config URL file!");
                return;
            }
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, from.getName());
        if (!par.isDirectory() && !par.mkdirs()) {
            throw new IOException("Could not make config dir?");
        }
        log.debug("Copying from {} to {}", from, to);
        Files.copy(from, to);
    }
}
