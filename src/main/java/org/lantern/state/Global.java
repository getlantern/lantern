package org.lantern.state;

public class Global {

    private final NUsers nusers = new NUsers();
    private final NPeers npeers = new NPeers();

    private int bytesEver;
    private int bps;

    public NPeers getNpeers() {
        return npeers;
    }

    public NUsers getNusers() {
        return nusers;
    }

    public int getBytesEver() {
        return bytesEver;
    }

    public void setBytesEver(int bytesEver) {
        this.bytesEver = bytesEver;
    }

    public int getBps() {
        return bps;
    }

    public void setBps(int bps) {
        this.bps = bps;
    }

}
