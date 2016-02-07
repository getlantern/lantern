package org.lantern.mobilesdk;

/**
 * Thrown to indicate that Lantern is not running.
 *
 * @author ox
 */
public class LanternNotRunningException extends Exception {
    public LanternNotRunningException(String msg, Throwable cause) {
        super(msg, cause);
    }
}
