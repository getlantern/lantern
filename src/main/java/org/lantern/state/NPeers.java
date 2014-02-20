package org.lantern.state;

import org.lantern.annotation.Keep;

@Keep
public class NPeers {
    private int online = 0;
    private int ever = 0;

    public int getOnline() {
        return online;
    }

    public void setOnline(int online) {
        this.online = online;
    }

    public int getEver() {
        return ever;
    }

    public void setEver(int ever) {
        this.ever = ever;
    }
}