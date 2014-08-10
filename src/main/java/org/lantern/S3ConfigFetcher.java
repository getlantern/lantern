package org.lantern;

import java.security.SecureRandom;
import java.util.Collection;
import java.util.Timer;
import java.util.TimerTask;

import org.lantern.event.Events;
import org.lantern.oauth.OauthUtils;
import org.lantern.proxy.FallbackProxy;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Optional;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class continually fetches new Lantern configuration files on S3, 
 * dispatching events to any interested classes when and if a new configuration
 * file is found.
 */
@Singleton
public class S3ConfigFetcher {

    private static final Logger log
        = LoggerFactory.getLogger(S3ConfigFetcher.class);

    private final SecureRandom random = new SecureRandom();
    
    private Timer configCheckTimer;

    private final Model model;
    private final OauthUtils oauth;

    /**
     * Creates a new class for fetching the Lantern config from S3.
     * 
     * @param model The persistent settings.
     * @param oauth OauthUtils for performing authenticated calls to controller
     */
    @Inject
    public S3ConfigFetcher(final Model model, OauthUtils oauth) {
        log.debug("Creating s3 config fetcher...");
        this.model = model;
        this.oauth = oauth;
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
            final Collection<FallbackProxy> fallbacks = config.getAllFallbacks();
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
            throw new InitException("No S3Config!  This shouldn't happen, since there's both a default S3Config available as well as one that we try to fetch remotely.");
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
        if (newConfig.isPresent()) {
            this.model.setS3Config(newConfig.get());
            return !newConfig.get().equals(config);
        } else {
            log.info("Couldn't get a remote S3 config, sticking with what we have");
            return false;
        }
    }

    /** Linear interpolation. */
    private double lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }

    private Optional<S3Config> fetchRemoteConfig() {
        String url = LanternClientConstants.CONTROLLER_URL + "/_ah/api/s3config/v1/s3config/get";
        try {
            // Note this call will block until a refresh token is available.
            // This behavior is non-obvious, but this will only return once
            // the user has logged in and accordingly provided a refresh
            // token.
            String cfgStr = oauth.getRequest(url);
            log.debug("Fetched config string:\n{}", cfgStr);
            S3Config cfg = 
                JsonUtils.OBJECT_MAPPER.readValue(cfgStr, S3Config.class);
            return Optional.of(cfg);
        } catch (Exception e) {
            log.error("Unable to get updated S3Config from network: {}", e.getMessage(), e);
            return Optional.absent();
        }
    }}
