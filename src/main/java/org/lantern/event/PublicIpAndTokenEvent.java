package org.lantern.event;

public class PublicIpAndTokenEvent {

    private final String refresh;

    public PublicIpAndTokenEvent(final String refresh) {
        this.refresh = refresh;
    }

    public String getRefresh() {
        return refresh;
    }

}
