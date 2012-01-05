package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.InvocationTargetException;
import java.security.GeneralSecurityException;
import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.io.IOUtils;
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
    
    private final File settingsFile;
    
    private final SettingsChangeImplementor implementor =
        new SettingsChangeImplementor();
    
    /**
     * Creates a new instance with all the default operations.
     */
    public SettingsIo() {
        this(new File(LanternUtils.configDir(), "settings.json"));
    }
    
    
    /**
     * Creates a new instance with custom settings typically used only in 
     * testing.
     * 
     * @param settingsFile The file where settings are stored.
     */
    public SettingsIo(final File settingsFile) {
        this.settingsFile = settingsFile;
    }

    /**
     * Reads settings from disk.
     * 
     * @return The {@link Settings} instance as read from disk.
     */
    public Settings read() {
        if (!settingsFile.isFile()) {
            final Internet internet = new Internet();
            final Platform platform = new Platform();
            final SystemInfo sys = new SystemInfo(internet, platform);
            final UserInfo user = new UserInfo();
            final Whitelist whitelist = new Whitelist();
            final Roster roster = new Roster();
            final Settings settings = new Settings(sys, user, whitelist, roster);
            
            // Don't write here because this takes place super early in the 
            // init sequence, and writing itself can request things that 
            // don't exist yet.
            //write(settings);
            return settings;
        }
        final ObjectMapper mapper = new ObjectMapper();
        InputStream is = null;
        try {
            is = LanternUtils.localDecryptInputStream(settingsFile);
            final String json = IOUtils.toString(is);
            log.info("Reading:\n{}", json);
            final Settings read = mapper.readValue(json, Settings.class);
            log.info("Built settings from disk: {}", read);
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
     * Writes the default settings object.
     */
    public void write() {
        write(LanternHub.settings());
    }
    
    /**
     * Applies the given settings, including serializing them.
     * 
     * @param settings The settings to apply.
     */
    public void write(final Settings settings) {
        final Map<String, LanternPresence> entries = settings.getRoster().getEntries();
        //log.info("Writing:\n{}", json);
        OutputStream os = null;
        try {
            
            settings.getRoster().setEntries(new HashMap<String, LanternPresence>());
            final String json = LanternUtils.jsonify(settings);
            os = LanternUtils.localEncryptOutputStream(settingsFile);
            os.write(json.getBytes("UTF-8"));
        } catch (final IOException e) {
            log.error("Error encrypting stream", e);
        } catch (final GeneralSecurityException e) {
            log.error("Error encrypting stream", e);
        } finally {
            IOUtils.closeQuietly(os);
            settings.getRoster().setEntries(entries);
        }
        
    }
    
    private final Map<String, Function<Object, String>> applyFuncs =
        new ConcurrentHashMap<String, Function<Object,String>>();
    
    {
        applyFuncs.put("api", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                LanternHub.api().processCall((Map<String, String>)obj);
                return "";
            }
        });
        applyFuncs.put("system", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                return applyChanges(obj, LanternHub.settings().getSystem());
            }
        });
        
        applyFuncs.put("user", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                return applyChanges(obj, LanternHub.settings().getUser());
            }
        });
        
        applyFuncs.put("whitelist", new Function<Object, String>() {
            @Override
            public String apply(final Object obj) {
                // TODO: How should we handle arrays? Tempting to force the
                // client to submit complete objects!!
                
                // MAYBE HAVE THE CLIENT SIDE SUBMIT THE FULL WHITELIST EACH TIME?
                //return applyChanges(obj, "whitelist", LanternHub.settings().getWhitelist());
                return "";
            }
        });
    }
    
    protected String applyChanges(final Object obj, 
        final Object propertiesBean) {
        final Map<String, Object> settings = (Map<String, Object>) obj;
        final Set<Entry<String, Object>> entries = settings.entrySet();
        for (final Entry<String, Object> entry : entries) {
            // We do the implementor first because it often checks to make sure
            // the value has actually changed before implementing any changes.
            setProperty(implementor, entry);
            setProperty(propertiesBean, entry);
        }
        return "";
    }


    private void setProperty(final Object bean, 
        final Entry<String, Object> entry) {
        final String key = entry.getKey();
        final Object val = entry.getValue();
        try {
            PropertyUtils.setSimpleProperty(bean, key, val);
        } catch (final IllegalAccessException e) {
            log.error("Could not set property", e);
        } catch (final InvocationTargetException e) {
            log.error("Could not set property", e);
        } catch (final NoSuchMethodException e) {
            log.error("Could not set property", e);
        }
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
        write();
    }
}
