package org.lantern.mobilesdk;

/**
 * Thrown to indicate that Lantern is not running.
 */
public class LanternNotRunningException extends Exception {
    public LanternNotRunningException(String msg) {
        super(msg);
    }

    public LanternNotRunningException(String msg, Throwable cause) {
        super(msg, cause);
    }
}
