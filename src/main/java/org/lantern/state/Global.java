package org.lantern.state;


public class Global {

    private final NUsers nusers = new NUsers();
    private final NPeers npeers = new NPeers();

    public NPeers getNpeers() {
        return npeers;
    }
    public NUsers getNusers() {
        return nusers;
    }

}
