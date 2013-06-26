package org.lantern;

import org.lantern.annotation.Keep;

/**
 * Enumeration of connectivity statuses.
 */
@Keep
public enum GoogleTalkState {

    notConnected,
    //LOGGING_OUT,
    connecting,
    connected, 
    LOGIN_FAILED
}
