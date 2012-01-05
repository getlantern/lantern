package org.lantern;

/**
 * Event for when the system proxy is turned on or off.
 */
public class ProxyingEvent {

    private final boolean proxying;

    public ProxyingEvent(final boolean proxying) {
        this.proxying = proxying;
    }

    public boolean isProxying() {
        return proxying;
    }

}
