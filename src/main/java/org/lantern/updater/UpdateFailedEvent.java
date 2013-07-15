package org.lantern.updater;

/**
 * An update could not be downloaded or installed.
 *
 */
public class UpdateFailedEvent {

    //FIXME: i18n
    private final String reason;

    public UpdateFailedEvent(String reason) {
        this.reason = reason;
    }

    public String getReason() {
        return reason;
    }
}
