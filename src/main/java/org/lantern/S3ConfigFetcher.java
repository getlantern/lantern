package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.security.SecureRandom;
import java.util.Collection;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.proxy.FallbackProxy;
import org.lantern.state.Model;
import org.lantern.state.Notification.MessageType;
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

    private static final Logger log = LoggerFactory
            .getLogger(S3ConfigFetcher.class);

    private static final String URL_FILENAME = ".lantern-configurl.txt";
    private static final String LOCAL_S3_CONFIG = ".s3config";

    private final SecureRandom random = new SecureRandom();

    private final Timer configCheckTimer = new Timer("S3-Config-Check", true);

    private final Model model;

    /**
     * Creates a new class for fetching the Lantern config from S3.
     * 
     * @param model
     *            The persistent settings.
     */
    public S3ConfigFetcher(final Model model) {
        log.debug("Creating s3 config fetcher...");
        this.model = model;
    }

    public void start() {
        log.debug("Starting config loading...");
        if (LanternUtils.isFallbackProxy()) {
            return;
        }
        final S3Config config = model.getS3Config();

        // Always check for a new config right away. We do this on the same
        // thread here because a lot depends on this value, particularly on
        // the first run of Lantern, and we want to make sure it takes priority.
        if (config != null) {
            // The config in the model could just be the default, so check
            // for actual fallbacks.
            final Collection<FallbackProxy> fallbacks = config.getFallbacks();
            if (fallbacks == null || fallbacks.isEmpty()) {
                recheck();
            } else {
                log.debug("Using existing config...");
                Events.asyncEventBus().post(config);
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

        }, (long) (minutesToSleep * 60000));
    }

    private void recheck() {
        recheckConfig();
        final S3Config config = model.getS3Config();
        final double newMinutesToSleep
        // Temporary network problems? Let's retry in a few seconds.
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

    private Optional<S3Config> fetchConfig() {
        final List<File> searchPath = Lists.newArrayList(
                SystemUtils.getUserHome(),
                SystemUtils.getUserDir());
        if (SystemUtils.IS_OS_WINDOWS) {
            searchPath.add(1, new File(System.getenv("APPDATA")));
        }

        Optional<String> cfgStr = readConfig(searchPath);

        if (!cfgStr.isPresent()) {
            log.error("Unable to read config url or local S3 config from {}",
                    searchPath);
            Events.asyncEventBus().post(
                    new MessageEvent(Tr.tr(MessageKey.NO_CONFIG),
                            MessageType.error));
            return Optional.absent();
        }

        return parseConfig(cfgStr.get());
    }

    private Optional<String> readConfig(Collection<File> searchPath) {
        for (File directory : searchPath) {
            log.debug("Looking for s3 configuration at: {}", directory);
            
            File localS3File = new File(directory, LOCAL_S3_CONFIG);
            log.debug("Attempting with local S3 file: {}", localS3File);
            if (localS3File.exists()) {
                Optional<String> cfgStr = fetchLocalConfig(localS3File);
                if (cfgStr.isPresent()) {
                    log.debug("Using local S3 config file: {}", localS3File);
                    return cfgStr;
                }
            }
            
            File urlFile = new File(directory, URL_FILENAME);
            log.debug("Attempting with url file: {}", urlFile);
            if (urlFile.exists()) {
                Optional<String> url = readUrlFromFile(urlFile);
                if (url.isPresent()) {
                    Optional<String> cfgStr = fetchRemoteConfig(url.get());
                    if (cfgStr.isPresent()) {
                        log.debug("Using S3 config url: {}", url.get());
                        return cfgStr;
                    }
                }
            }
        }

        return Optional.absent();
    }

    public static Optional<String> readUrlFromFile(File urlFile) {
        if (!urlFile.isFile()) {
            log.error("Still no config file at {}", urlFile);
            return Optional.absent();
        }

        try {
            final String folder =
                    FileUtils.readFileToString(urlFile, "UTF-8");
            return Optional.of(LanternConstants.S3_CONFIG_BASE_URL
                    + folder.trim()
                    + "/config.json");
        } catch (final IOException e) {
            log.error("Couldn't read config URL file?", e);
        }

        return Optional.absent();
    }

    public static Optional<String> fetchRemoteConfig(String url) {
        final HttpClient client = HttpClientFactory.newDirectClient();
        final HttpGet get = new HttpGet(url);
        InputStream is = null;
        try {
            final HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            final String cfgStr = IOUtils.toString(is);
            return Optional.of(cfgStr);
        } catch (final IOException e) {
            log.error("Couldn't fetch config at " + url, e);
        } finally {
            IOUtils.closeQuietly(is);
            get.reset();
        }
        return Optional.absent();
    }

    public static Optional<String> fetchLocalConfig(File localS3File) {
        try {
            return Optional.of(FileUtils.readFileToString(localS3File));
        } catch (Exception e) {
            log.warn(String.format(
                    "Couldn't read local S3 configuration from %1$s: %2$s",
                    localS3File.getAbsolutePath(), e.getMessage()), e);
        }
        return Optional.absent();
    }

    public static Optional<S3Config> parseConfig(String cfgStr) {
        try {
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
            log.error("Couldn't parse config {}", cfgStr, e);
        }
        return Optional.absent();
    }
}
