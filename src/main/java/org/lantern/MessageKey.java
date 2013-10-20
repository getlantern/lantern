package org.lantern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Keys for looking up translated versions of messages. This makes sure at
 * launch time that all keys do in fact exist.
 */
public enum MessageKey {

    ALREADY_ADDED,
    
    ERROR_CONNECTING_TO, ERROR_ADDING_FRIEND, ERROR_UPDATING_FRIEND, 
    ERROR_EMAILING_FRIEND, ERROR_EMAILING_NEW_FRIEND, ERROR_ADDING_NEW_FRIEND, 
    PROCESSING_FRIEND, ADDED_FRIEND, REMOVED_FRIEND, ERROR_REMOVING_FRIEND, 
    LOGGED_IN, CONFIGURING_CONNECTION, CHECKING_INVITE, INVITED, STUN_SERVER_LOOKUP;
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private MessageKey() {
        // Early runtime check to ensure the key actually exists.
        final String key = "BACKEND_"+this.toString();
        System.err.println("LOOKING UP "+key);
        final String translated = Tr.tr(key);
        if (translated.equals(key)) {
            final String msg = "No entry for key! "+key;
            log.error(msg);
            if (LanternUtils.isDevMode()) {
                log.debug("Exiting with missing key in dev mode!");
                System.exit(1);
            }
            throw new Error(msg);
        }
    }
}
