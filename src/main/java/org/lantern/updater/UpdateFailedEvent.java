package org.lantern.updater;

import java.net.URI;

/**
 * An update could not be downloaded or installed.
 *
 */
public class UpdateFailedEvent {

    //FIXME: i18n
    private final String reason;
    private final URI updateURI;

    public UpdateFailedEvent(URI updateURI, String reason) {
        this.updateURI = updateURI;
        this.reason = reason;
    }

    public String getReason() {
        return reason;
    }

    public URI getUpdateURI() {
        return updateURI;
    }
}
