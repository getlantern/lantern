package org.lantern.state;

import org.lantern.annotation.Keep;

@Keep
public class NUsers {
    private long online;
    private long ever;

    public long getOnline() {
        return online;
    }

    public void setOnline(long online) {
        this.online = online;
    }

    public long getEver() {
        return ever;
    }

    public void setEver(long ever) {
        this.ever = ever;
    }
}