package org.lantern.event;

public class ProxyAndTokenEvent {

    private final String refresh;

    public ProxyAndTokenEvent(final String refresh) {
        this.refresh = refresh;
    }

    public String getRefresh() {
        return refresh;
    }

}
