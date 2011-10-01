package org.lantern;

import java.util.Locale;
import java.util.ResourceBundle;

/**
 * Utility class used for using xgettext to generate po files for translation,
 * but that uses {@link ResourceBundle}s underneath the hood.
 */
public class I18n {
    
    private I18n() {}
    
    private static final ResourceBundle rb = 
        Utf8ResourceBundle.getBundle("LanternResourceBundle", 
            Locale.getDefault());
    
    public static String tr(final String toTrans) {
        final int len = Math.min(toTrans.length(), 
            LanternConstants.I18N_KEY_LENGTH);
        final String normalized = 
            toTrans.replaceAll(" ", "_").substring(0, len);
        return rb.getString(normalized);
    }
}