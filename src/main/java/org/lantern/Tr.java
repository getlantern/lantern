package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Locale;
import java.util.Map;

import org.apache.commons.lang3.StringUtils;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Charsets;
import com.google.common.io.Files;

/**
 * Utility class used for using existing translation files integrated with
 * Transifex to easily fetch translated strings.
 */
public class Tr {
    
    private static final Logger LOG = LoggerFactory.getLogger(Tr.class);
    
    private Tr() {}
    
    private static final File prod = new File("lantern-ui/locale");
    private static final File dir = 
            prod.isDirectory() ? prod : new File("lantern-ui/app/locale");
    
    private static Map<String, String> trans;
    
    private static Map<String, String> en_us;
    
    static {
        reload();
    }
    
    public static String tr(final MessageKey key) {
        if (key == null) {
            LOG.error("Null translation key at: "+ThreadUtils.dumpStack());
            throw new IllegalArgumentException("Null translation key");
        }
        return tr("BACKEND_"+key.toString());
    }
    
    public static String tr(final String key) {
        if (StringUtils.isBlank(key) ) {
            LOG.error("Null translation key at: "+ThreadUtils.dumpStack());
            throw new IllegalArgumentException("Null translation key");
        }
        final String translated = trans.get(key);
        
        if (StringUtils.isNotBlank(translated)) {
            return translated;
        }
        
        // Fallback to english if it's not there.
        final String english = en_us.get(key);
        if (StringUtils.isNotBlank(english)) {
            return english;
        }
        return key;
    }

    public static void reload() {
        final String localeStr = Locale.getDefault().toString() + ".json";
        
        final File usLocaleFile = new File(dir, "en_US.json");
        final File translated = new File(dir, localeStr);

        // If the translations aren't there, use en_US.
        final File localeFile = 
                translated.isFile() ? translated : usLocaleFile;
        
        try {
            final String json = Files.toString(localeFile, Charsets.UTF_8);
            final String usJson = Files.toString(usLocaleFile, Charsets.UTF_8);
            trans = JsonUtils.OBJECT_MAPPER.readValue(json, Map.class);
            en_us = JsonUtils.OBJECT_MAPPER.readValue(usJson, Map.class);
        } catch (final IOException e) {
            LOG.error("Could not map translations?", e);
            throw new Error("Could not map translations?", e);
        }
    }
}