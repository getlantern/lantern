package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.security.SecureRandom;
import java.util.Collection;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.lantern.event.Events;
import org.lantern.proxy.FallbackProxy;
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Optional;
import com.google.common.collect.Lists;

/**
 * This class continually fetches new Lantern configuration files on S3, 
 * dispatching events to any interested classes when and if a new configuration
 * file is found.
 */
public class S3ConfigFetcher {

    private static final Logger log
        = LoggerFactory.getLogger(S3ConfigFetcher.class);

    // DRY: wrapper.install4j and configureUbuntu.txt
    private static final String URL_FILENAME = ".lantern-configurl.txt";

    private final SecureRandom random = new SecureRandom();
    
    private Timer configCheckTimer;

    private final Model model;

    private HttpClientFactory httpClientFactory;

    /**
     * Creates a new class for fetching the Lantern config from S3.
     * 
     * @param model The persistent settings.
     */
    public S3ConfigFetcher(final Model model, 
            final HttpClientFactory httpClientFactory) {
        log.debug("Creating s3 config fetcher...");
        this.model = model;
        this.httpClientFactory = httpClientFactory;
        Events.register(this);
    }
    
    public void init() throws InitException {
        log.debug("Starting config loading...");
        if (LanternUtils.isFallbackProxy()) {
            return;
        }
        final S3Config config = model.getS3Config();
        
        // Always check for a new config right away. We do this on the same
        // thread here because a lot depends on this value, particularly on
        // the first run of Lantern, and we want to make sure it takes priority.
        if (config != null) {
            log.debug("Stored S3 config: {}", config);
            // The config in the model could just be the default, so check
            // for actual fallbacks.
            final Collection<FallbackProxy> fallbacks = config.getFallbacks();
            if (fallbacks == null || fallbacks.isEmpty()) {
                downloadAndCompareConfig();
            } else {
                log.debug("Using existing config...");
                //Events.asyncEventBus().post(config);
            }
        } else {
            downloadAndCompareConfig();
        }
        if (model.getS3Config() == null) {
            throw new InitException("Still could not fetch S3 config");
        }
    }
    
    synchronized public void stop() {
        configCheckTimer.cancel();
        configCheckTimer = null;
    }
    
    public void start() {
        scheduleConfigRecheck(0.0);
    }
    
    private void scheduleConfigRecheck(final double minutesToSleep) {
        log.debug("Scheduling config check...");
        if (configCheckTimer == null) {
            configCheckTimer = new Timer("S3-Config-Check", true);
        }
        configCheckTimer.schedule(new TimerTask() {
            @Override
            public void run() {
                recheck();
            }
            
        }, (long)(minutesToSleep * 60000));
    }

    synchronized private void recheck() {
        boolean changed = downloadAndCompareConfig();
        final S3Config config = model.getS3Config();
        if (changed) {
            log.info("Configuration changed");
            Events.eventBus().post(config);
        } else {
            log.debug("Configuration unchanged.");
        }
        final double newMinutesToSleep
        // Temporary network problems?  Let's retry in a few seconds.
        = (config == null) ? 0.2
                           : lerp(config.getMinpoll(),
                                  config.getMaxpoll(),
                                  random.nextDouble());
        
        scheduleConfigRecheck(newMinutesToSleep);
    }


    private boolean downloadAndCompareConfig() {
        log.debug("Rechecking configuration");
        final Optional<S3Config> newConfig = fetchRemoteConfig();
        if (!newConfig.isPresent()) {
            log.error("Couldn't get new config.");
            return false;
        }

        final S3Config config = this.model.getS3Config();
        this.model.setS3Config(newConfig.get());


        if (config == null) {
            log.warn("Rechecking config with no old one.");
            return true;
        } else {
            return !newConfig.get().equals(config);
        }
    }

    /** Linear interpolation. */
    private double lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }

    private Optional<String> urlFromFile(File file) {
        try {
            final String folder = 
                    FileUtils.readFileToString(file, "UTF-8");
            log.debug("Read folder from URL file: {}", folder);
            return Optional.of(urlFromFolder(folder));
        } catch (final IOException e) {
            log.error("Couldn't read config URL file?", e);
        }

        return Optional.absent();
    }
    
    public static String urlFromFolder(final String folder) {
        return LanternConstants.S3_CONFIG_BASE_URL
                + folder.trim()
                + "/config.json";
    }
    
    private Optional<S3Config> fetchRemoteConfig() {
        try {
            final HttpClient direct = this.httpClientFactory.newDirectClient();
            return fetchRemoteConfig(direct);
        } catch (final IOException e) {
            final HttpClient proxied = this.httpClientFactory.newProxiedClient();
            try {
                return fetchRemoteConfig(proxied);
            } catch (IOException ioe) {
                log.error("Still could not fetch S3 config using fallback.");
                return Optional.absent();
            }
        }
    }

    private Optional<S3Config> fetchRemoteConfig(final HttpClient client)
            throws IOException {
        Optional<String> url = determineUrl();
        if (!url.isPresent()) {
            log.error("URL initialization failed.");
            return Optional.absent();
        }                
        log.debug("Fetching config at {}", url.get());
        final HttpGet get = new HttpGet(url.get());
        InputStream is = null;
        try {
            final HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            final String cfgStr = IOUtils.toString(is);
            log.debug("Fetched config:\n{}", cfgStr);
            final S3Config cfg = 
                JsonUtils.OBJECT_MAPPER.readValue(cfgStr, S3Config.class);
            return Optional.of(cfg);
        } finally {
            IOUtils.closeQuietly(is);
            get.reset();
        }
    }

    private Optional<String> determineUrl() throws IOException {
        final File curDir = new File(SystemUtils.getUserDir(), URL_FILENAME);
        final Collection<File> filesToTry = Lists.newArrayList(
                new File(SystemUtils.getUserHome(), URL_FILENAME),
                curDir
        );
        if (SystemUtils.IS_OS_WINDOWS) {
            filesToTry.add(new File(System.getenv("APPDATA")));
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        if (!par.isDirectory() && !par.mkdirs()) {
            log.error("Could not make config dir at "+par);
            throw new IOException("Could not make config dir at "+par);
        }
        
        for (final File from : filesToTry) {
            if (!from.getParentFile().isDirectory()) {
                log.error("Parent file is not a directory at {}", 
                        from.getParentFile());
            }
            if (from.isFile()) {
                log.debug("Using url from file: {}", from);
                return urlFromFile(from);
            } else {
                log.debug("No config file at {}", from);
            }
        }
    
        //  If we exit the loop and end up here it means we could not find
        // a config file to copy in any of the expected locations.
        log.error("Config file not found at any of {}", filesToTry);
        return Optional.absent();
    }


    private boolean isFileNewer(final File file, final File reference) {
        if (reference == null || !reference.isFile()) {
            return true;
        }
        return FileUtils.isFileNewer(file, reference);
    }
}
