package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.security.SecureRandom;
import java.util.Arrays;
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
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Optional;
import com.google.common.io.Files;

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

    private final Optional<String> url;

    private final SecureRandom random = new SecureRandom();
    
    private final Timer configCheckTimer = new Timer("S3-Config-Check", true);

    private final Model model;

    /**
     * Creates a new class for fetching the Lantern config from S3.
     * 
     * @param model The persistent settings.
     */
    public S3ConfigFetcher(final Model model) {
        log.debug("Creating s3 config manager...");
        this.model = model;
        this.url = readUrl();
    }
    

    public void start() {
        log.debug("Starting config loading...");
        if (LanternUtils.isFallbackProxy()) {
            return;
        }
        if (!this.url.isPresent()) {
            log.debug("No url to use for downloading config");
            return;
        }
        final S3Config config = model.getS3Config();
        
        // Always check for a new config right away. We do this on the same
        // thread here because a lot depends on this value, particularly on
        // the first run of Lantern, and we want to make sure it takes priority.
        if (config != null) {
            Events.asyncEventBus().post(config);
            
            if (config.getFallbacks().isEmpty()) {
                recheck();
            } else {
                // If we've already got valid fallbacks, thread this so we
                // don't hold up the rest of Lantern initialization.
                scheduleConfigRecheck(0.0);
            }
        } else {
            recheck();
        }
        
    }
    
    private void scheduleConfigRecheck(final double minutesToSleep) {
        log.debug("Scheduling config check...");
        configCheckTimer.schedule(new TimerTask() {
            @Override
            public void run() {
                recheck();
            }
            
        }, (long)(minutesToSleep * 60000));
    }

    private void recheck() {
        recheckConfig();
        final S3Config config = model.getS3Config();
        final double newMinutesToSleep
        // Temporary network problems?  Let's retry in a few seconds.
        = (config == null) ? 0.2
                           : lerp(config.getMinpoll(),
                                  config.getMaxpoll(),
                                  random.nextDouble());
        
        scheduleConfigRecheck(newMinutesToSleep);
    }


    private void recheckConfig() {
        log.debug("Rechecking configuration");
        final Optional<S3Config> newConfig = fetchConfig();
        if (!newConfig.isPresent()) {
            log.error("Couldn't get new config.");
            return;
        }
        
        final S3Config config = this.model.getS3Config();
        this.model.setS3Config(newConfig.get());
        
        
        boolean changed;
        if (config == null) {
            log.warn("Rechecking config with no old one.");
            changed = true;
        } else {
            changed = !newConfig.get().equals(config);
        }
        if (changed) {
            log.info("Configuration changed! Reapplying...");
            Events.eventBus().post(newConfig.get());
        } else {
            log.debug("Configuration unchanged.");
        }
    }

    /** Linear interpolation. */
    private double lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }

    private static Optional<String> readUrl() {
        File file = new File(LanternClientConstants.CONFIG_DIR,
                             URL_FILENAME);
        if (!file.isFile()) {
            try {
                copyUrlFile();
                if (!file.isFile()) {
                    log.error("Still no config file at {}", file);
                }
            } catch (final IOException e) {
                log.warn("Couldn't copy config URL file?", e);
                return Optional.absent();
            }
        }
        if (file.isFile()) {
            try {
                final String folder = FileUtils.readFileToString(file, "UTF-8");
                return Optional.of(LanternConstants.S3_CONFIG_BASE_URL
                    + folder
                    + "/config.json");
            } catch (final IOException e) {
                log.error("Couldn't read config URL file?", e);
            }
        } else {
            log.error("No config URL file at {}", file);
        }
        return Optional.absent();
    }

    private Optional<S3Config> fetchConfig() {
        if (!url.isPresent()) {
            log.error("URL initialization failed.");
            return Optional.absent();
        }
        final HttpClient client = HttpClientFactory.newDirectClient();
        final HttpGet get = new HttpGet(url.get());
        InputStream is = null;
        try {
            final HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            final String cfgStr = IOUtils.toString(is);
            final S3Config cfg = 
                JsonUtils.OBJECT_MAPPER.readValue(cfgStr, S3Config.class);
            log.debug("Controller: " + cfg.getController());
            log.debug("Minimum poll time: " + cfg.getMinpoll());
            log.debug("Maximum poll time: " + cfg.getMaxpoll());
            for (final FallbackProxy fp : cfg.getFallbacks()) {
                log.debug("Proxy: " + fp);
            }
            return Optional.of(cfg);
        } catch (final IOException e) {
            log.error("Couldn't fetch config at "+url.get(), e);
        } finally {
            IOUtils.closeQuietly(is);
            get.reset();
        }
        return Optional.absent();
    }

    private static void copyUrlFile() throws IOException {
        log.debug("Copying config URL file");
        final Collection<File> directoriesToTry = Arrays.asList(
            new File(SystemUtils.USER_HOME),
            new File(SystemUtils.USER_DIR)
        );
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, URL_FILENAME);
        if (!par.isDirectory() && !par.mkdirs()) {
            log.error("Could not make config dir at "+par);
            throw new IOException("Could not make config dir at "+par);
        }
        
        for (final File directory : directoriesToTry) {
            final File from = new File(directory, URL_FILENAME);
            if (from.isFile()) {
                log.debug("Copying from {} to {}", from, to);
                Files.copy(from, to);
                return;
            } else {
                log.debug("No config file at {}", from);
            }
        }
        
        // If we exit the loop and end up here it means we could not find
        // a config file to copy in any of the expected locations.
        log.error("Config file not found in any of {}", directoriesToTry);
    }
}
