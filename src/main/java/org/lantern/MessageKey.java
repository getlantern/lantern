package org.lantern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public enum MessageKey {

    ALREADY_ADDED,
    
    ERROR_CONNECTING_TO;
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private MessageKey() {
        // Early runtime check to ensure the key actually exists.
        final String key = "BACKEND_"+this.toString();
        System.err.println("LOOKING UP "+key);
        final String translated = Tr.tr(key);
        if (translated.equals(key)) {
            final String msg = "No entry for key! "+key;
            log.error(msg);
            throw new Error(msg);
        }
    }
}
