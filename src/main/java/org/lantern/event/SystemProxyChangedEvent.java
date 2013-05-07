package org.lantern.event;

public class SystemProxyChangedEvent {

    private final boolean systemProxy;

    public SystemProxyChangedEvent(final boolean systemProxy) {
        this.systemProxy = systemProxy;
    }

    public boolean isSystemProxy() {
        return systemProxy;
    }

    @Override
    public String toString() {
        return "SystemProxyChangedEvent [systemProxy=" + systemProxy + "]";
    }

}
