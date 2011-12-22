package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class is responsible for taking any actions required to serialize
 * settings to disk as well as to take actions based on settings changes.
 */
public class SettingsIo {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final File launchdPlist;
    
    public final File settingsFile;
    
    /**
     * Creates a new instance with all the default operations.
     */
    public SettingsIo() {
        this(LanternConstants.LAUNCHD_PLIST, 
            new File(LanternUtils.configDir(), "settings.json"));
    }
    
    
    /**
     * Creates a new instance with custom settings typically used only in 
     * testing.
     * 
     * @param launchdPlist The plist file to use for launchd.
     * @param settingsFile The file where settings are stored.
     */
    public SettingsIo(final File launchdPlist, final File settingsFile) {
        this.launchdPlist = launchdPlist;
        this.settingsFile = settingsFile;
    }

    public Settings read() {
        if (!settingsFile.isFile()) {
            final Settings settings = new Settings();
            //write(settings);
            return settings;
        }
        final ObjectMapper mapper = new ObjectMapper();
        InputStream is = null;
        try {
            is = LanternUtils.localDecryptInputStream(settingsFile);
            final String json = IOUtils.toString(is);
            //log.info("Reading:\n{}", json);
            final Settings read = mapper.readValue(json, Settings.class);
            return read;
        } catch (final IOException e) {
            log.error("Could not read settings", e);
        } catch (final GeneralSecurityException e) {
            log.error("Could not read settings", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        settingsFile.delete();
        final Settings settings = new Settings();
        //write(settings);
        return settings;
    }
    
    /**
     * Applies the given settings, including serializing them.
     * 
     * @param settings The settings to apply.
     */
    public void write(final Settings settings) {
        final SystemInfo si = settings.getSystem();
        setStartAtLogin(si.isStartAtLogin());

        final String json = LanternUtils.jsonify(settings);
        //log.info("Writing:\n{}", json);
        OutputStream os = null;
        try {
            os = LanternUtils.localEncryptOutputStream(settingsFile);
            os.write(json.getBytes("UTF-8"));
        } catch (final IOException e) {
            log.error("Error encrypting stream", e);
        } catch (final GeneralSecurityException e) {
            log.error("Error encrypting stream", e);
        } finally {
            IOUtils.closeQuietly(os);
        }
        
    }
    
    private void setStartAtLogin(final boolean start) {
        if (SystemUtils.IS_OS_MAC_OSX && this.launchdPlist.isFile()) {
            LanternUtils.replaceInFile(this.launchdPlist, 
                "<"+!start+"/>", "<"+start+"/>");
        } else if (SystemUtils.IS_OS_WINDOWS) {
            // TODO: Make this work on Windows and Linux!! Tricky on Windows
            // because it's not clear we have permissions to modify the
            // registry in all cases.
        }
    }
}
