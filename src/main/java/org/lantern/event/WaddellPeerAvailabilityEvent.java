package org.lantern.event;

public class WaddellPeerAvailabilityEvent {

    private final String encryptedJid;
    private final String id;
    private final String waddellAddr;
    private final String country;
    private boolean available;

    public static WaddellPeerAvailabilityEvent available(String encryptedJid,
            String id,
            String waddellAddr,
            String country) {
        return new WaddellPeerAvailabilityEvent(encryptedJid, id, waddellAddr,
                country, true);
    }

    public static WaddellPeerAvailabilityEvent unavailable(String encryptedJid) {
        return new WaddellPeerAvailabilityEvent(encryptedJid, null, null, null,
                false);
    }

    private WaddellPeerAvailabilityEvent(String encryptedJid, String id,
            String waddellAddr, String country, boolean available) {
        super();
        this.encryptedJid = encryptedJid;
        this.id = id;
        this.waddellAddr = waddellAddr;
        this.country = country;
        this.available = available;
    }

    public String getEncryptedJid() {
        return encryptedJid;
    }

    public String getId() {
        return id;
    }

    public String getWaddellAddr() {
        return waddellAddr;
    }

    public String getCountry() {
        return country;
    }

    public boolean isAvailable() {
        return available;
    }

    @Override
    public String toString() {
        return "WaddellPeerAvailabilityEvent [encryptedJid=" + encryptedJid
                + ", id=" + id + ", waddellAddr=" + waddellAddr + ", country="
                + country + ", available=" + available + "]";
    }

}
