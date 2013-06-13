package org.lantern;

import org.lantern.state.NPeers;
import org.lantern.state.NUsers;

public class Country {

    private String code;
    private String name;
    private boolean censors;

    private long bps;
    private long bytesEver;

    private NUsers nusers = new NUsers();
    private NPeers npeers = new NPeers();

    public Country() {

    }

    public Country(final String code, final String name, final boolean cens) {
        this.code = code;
        this.name = name;
        this.censors = cens;
    }

    public void setCode(final String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public void setName(final String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public void setCensors(final boolean censors) {
        this.censors = censors;
    }

    public boolean isCensors() {
        return censors;
    }

    public long getBps() {
        return bps;
    }

    public void setBps(long bps) {
        this.bps = bps;
    }

    public long getBytesEver() {
        return bytesEver;
    }

    public void setBytesEver(long bytesEver) {
        this.bytesEver = bytesEver;
    }

    public NUsers getNusers() {
        return nusers;
    }

    public void setNusers(NUsers nusers) {
        this.nusers = nusers;
    }

    public NPeers getNpeers() {
        return npeers;
    }

    public void setNpeers(NPeers npeers) {
        this.npeers = npeers;
    }

}
