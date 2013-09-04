package org.lantern.state;

import org.lantern.annotation.Keep;

@Keep
public class Global {

    private final NUsers nusers = new NUsers();
    private final NPeers npeers = new NPeers();

    private long bytesEver;
    private int bps;

    public NPeers getNpeers() {
        return npeers;
    }

    public NUsers getNusers() {
        return nusers;
    }

    public long getBytesEver() {
        return bytesEver;
    }

    public void setBytesEver(long bytesEver) {
        this.bytesEver = bytesEver;
    }

    public int getBps() {
        return bps;
    }

    public void setBps(int bps) {
        this.bps = bps;
    }

}
