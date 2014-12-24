package org.lantern.proxy.pt;

/**
 * When running in Give mode, this event is generated everytime that flashlight
 * connects to the waddell server. On each connection, we will get a new id.
 */
public class ConnectedToWaddellEvent {
    private String id;
    private String waddellAddr;

    public ConnectedToWaddellEvent(String id, String waddellAddr) {
        super();
        this.id = id;
        this.waddellAddr = waddellAddr;
    }

    public String getId() {
        return id;
    }

    public String getWaddellAddr() {
        return waddellAddr;
    }

}
