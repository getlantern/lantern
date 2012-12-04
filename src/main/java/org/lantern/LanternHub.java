package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.SecureRandom;
import java.util.concurrent.atomic.AtomicReference;
import java.util.zip.GZIPInputStream;

import org.apache.commons.io.IOUtils;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.InMemoryCookieTracker;
import org.lantern.event.SettingsStateEvent;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.maxmind.geoip.LookupService;

/**
 * Class for accessing all of the core modules used in Lantern.
 */
public class LanternHub {

    private static final Logger LOG = LoggerFactory.getLogger(LanternHub.class);
    
    private static final AtomicReference<SecureRandom> secureRandom =
        new AtomicReference<SecureRandom>(new SecureRandom());
    
    private static final File UNZIPPED = 
        new File(LanternConstants.DATA_DIR, "GeoIP.dat");
    
    private static final AtomicReference<LookupService> lookupService = 
        new AtomicReference<LookupService>();

    private static final AtomicReference<CookieTracker> cookieTracker =
        new AtomicReference<CookieTracker>();
    
    private static final AtomicReference<Censored> censored =
        new AtomicReference<Censored>();
    
    private static final AtomicReference<SettingsIo> settingsIo =
        new AtomicReference<SettingsIo>();
    private static final AtomicReference<HttpsEverywhere> httpsEverywhere =
        new AtomicReference<HttpsEverywhere>();
    
    private static final AtomicReference<Settings> settings = 
        new AtomicReference<Settings>();
    
    static {
        // start with an UNSET settings object until loaded
        settings.set(new Settings());
        postSettingsState();
        
        /*
        if (!LanternConstants.ON_APP_ENGINE) {
            // if they were successfully loaded, save the most current state when exiting.
            Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
    
                @Override
                public void run() {
                    SettingsState ss = settings().getSettings();
                    if (ss.getState() == SettingsState.State.SET) {
                        LOG.info("Writing settings");
                        LanternHub.settingsIo().write(LanternHub.settings());
                        LOG.info("Finished writing settings...");
                    }
                    else {
                        LOG.warn("Not writing settings, state was {}", ss.getState());
                    }
                }
                
            }, "Write-Settings-Thread"));
        }
        */
    }
    
    public static LookupService getGeoIpLookup() {
        synchronized (lookupService) {
            if (lookupService.get() == null) {
                lookupService.set(buildLookupService());
            }
            return lookupService.get();
        }
    }
    
    private static LookupService buildLookupService() {
        if (!UNZIPPED.isFile())  {
            final File file = new File("GeoIP.dat.gz");
            GZIPInputStream is = null;
            OutputStream os = null;
            try {
                is = new GZIPInputStream(new FileInputStream(file));
                os = new FileOutputStream(UNZIPPED);
                IOUtils.copy(is, os);
            } catch (final IOException e) {
                LOG.error("Error expanding file?", e);
            } finally {
                IOUtils.closeQuietly(is);
                IOUtils.closeQuietly(os);
            }
        }
        try {
            return new LookupService(UNZIPPED, 
                    LookupService.GEOIP_MEMORY_CACHE);
        } catch (final IOException e) {
            LOG.error("Could not create LOOKUP service?");
        }
        return null;
    }

    public static SecureRandom secureRandom() {
        return secureRandom.get();
    }

    public static CookieTracker cookieTracker() {
        synchronized (cookieTracker) {
            if (cookieTracker.get() == null) {
                resetCookieTracker();
            }
            return cookieTracker.get();
        }
    }
    
    protected static void resetCookieTracker() {
        cookieTracker.set(new InMemoryCookieTracker());
    }
    
    public static Censored censored() {
        synchronized (censored) {
            if (censored.get() == null) {
                censored.set(new DefaultCensored());
            }
            return censored.get();
        }
    }

    /*
    public static Whitelist whitelist() {
        return settings().getWhitelist();
    }
    
    public static Platform platform() {
        return settings().getPlatform();
    }
    
    public static SettingsIo settingsIo() {
        synchronized (settingsIo) {
            if (settingsIo.get() == null) {
                final SettingsIo io = new SettingsIo(
                    new DefaultEncryptedFileService(new DefaultLocalCipherProvider()));
                settingsIo.set(io);
            }
            return settingsIo.get();
        }
    }
    */
    
    public static Settings settings() {
        return settings.get();
    }

    public static void resetSettings(boolean retainCLIOptions) {
        /*
        final Settings old = settings.get();
        final SettingsIo io = LanternHub.settingsIo();
        LOG.info("Setting settings...");
        try {
            settings.set(io.read());
        } catch (final Throwable t) {
            LOG.error("Caught throwable resetting settings: {}", t);
        }
       
        // retain any CommandLineSettings to the newly loaded settings
        // if requested.
        final Settings cur = settings();
        if (retainCLIOptions == true && cur != null && old != null) {
            try {
                old.copyCLI(cur);
            }
            catch (final Throwable t) {
                LOG.error("error copying command line settings! {}", t);
            }
        }
        */
        
        postSettingsState();
        throw new UnsupportedOperationException();
    }
   
    private static void postSettingsState() {
        Events.asyncEventBus().post(new SettingsStateEvent(settings().getSettings()));
    }

    public static HttpsEverywhere httpsEverywhere() {
        synchronized (httpsEverywhere) {
            if (httpsEverywhere.get() == null) {
                httpsEverywhere.set(new HttpsEverywhere());
            }
            return httpsEverywhere.get();
        }
    }
    
    public static void resetUserConfig() {
        /*
        // resets user specific configuration.
        final Settings set = settings();
        set.setEmail("");
        set.setPassword("");
        set.setStoredPassword("");
        set.setPasswordSaved(false);
        set.getTransfers().setDownTotalLifetime(0);
        set.getTransfers().setUpTotalLifetime(0);

        TrustedContactsManager tcm = trustedContactsManager.get();
        if (tcm != null) {
            tcm.clearTrustedContacts();
        }
        // TODO: FIX RESET IN GENERAL!!
        //xmppHandler().resetRoster();
        //resetTrustedPeerProxyManager();
        resetCookieTracker();
        statsTracker().resetUserStats();
        */
        throw new UnsupportedOperationException();
    }
    
    /**
     * This should do whatever is necessary to reset back to 'factory' defaults. 
     */
    public static void destructiveFullReset() throws IOException {
        /*
        LanternHub.localCipherProvider().reset();
        if (LanternConstants.DEFAULT_SETTINGS_FILE.isFile()) {
            FileUtils.forceDelete(LanternConstants.DEFAULT_SETTINGS_FILE);
        }
        LanternHub.resetSettings(true); // does not affect command line though...
        LanternHub.resetUserConfig(); // among others, TrustedContacts...
        */
        throw new UnsupportedOperationException();
    }
}
