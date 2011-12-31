package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Function;

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

    /**
     * Reads settings from disk.
     * 
     * @return The {@link Settings} instance as read from disk.
     */
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
            log.info("Setting start at login to "+start);
            LanternUtils.replaceInFile(this.launchdPlist, 
                "<"+!start+"/>", "<"+start+"/>");
        } else if (SystemUtils.IS_OS_WINDOWS) {
            // TODO: Make this work on Windows and Linux!! Tricky on Windows
            // because it's not clear we have permissions to modify the
            // registry in all cases.
        }
    }


    private final Map<String, Function<Object, String>> applyFuncs =
        new ConcurrentHashMap<String, Function<Object,String>>();
    
    {
        applyFuncs.put("system", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                final Map<String, Object> sys = (Map<String, Object>) obj;
                final Set<Entry<String, Object>> entries = sys.entrySet();
                for (final Entry<String, Object> entry : entries) {
                    final String key = entry.getKey();
                    if ("startAtLogin".equalsIgnoreCase(key)) {
                        setStartAtLogin(toBooleanValue(entry));
                    } else if ("systemProxy".equalsIgnoreCase(key)) {
                    } else if ("connectOnLaunch".equalsIgnoreCase(key)) {
                    } else if ("port".equalsIgnoreCase(key)) {
                    } else if ("location".equalsIgnoreCase(key)) {
                    } else {
                        log.error("No match for key: {}", key);
                    }
                }
                return "";
            }
        });
        
        applyFuncs.put("user", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                final Map<String, Object> sys = (Map<String, Object>) obj;
                final Set<Entry<String, Object>> entries = sys.entrySet();
                for (final Entry<String, Object> entry : entries) {
                    final String key = entry.getKey();
                    if ("mode".equalsIgnoreCase(key)) {
                    } else {
                        log.error("No match for key: {}", key);
                    }
                }
                return "";
            }
        });
        
        applyFuncs.put("whitelist", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                // TODO: How should we handle arrays? Tempting to force the
                // client to submit complete objects!!
                return "";
            }
        });
    }

    private boolean toBooleanValue(final Entry<String, Object> entry) {
        final Object obj = entry.getValue();
        log.info("Object: {}", obj);
        log.info("Class: {}", obj.getClass());
        return ((Boolean)obj).booleanValue();
    }
    
    public void apply(final Map<String, Object> update) {
        final Set<Entry<String, Object>> entries = update.entrySet();
        for (final Entry<String, Object> entry : entries) {
            final Function<Object, String> func = 
                applyFuncs.get(entry.getKey());
            if (func != null) {
                func.apply(entry.getValue());
            } else {
                log.warn("Received request for unmapped func {} in "+applyFuncs, 
                    func);
            }
        }
    }
}
