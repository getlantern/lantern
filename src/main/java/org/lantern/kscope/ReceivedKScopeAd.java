package org.lantern.kscope;

public final class ReceivedKScopeAd {
    private String from;
    private LanternKscopeAdvertisement ad;

    public ReceivedKScopeAd(String from, LanternKscopeAdvertisement ad) {
        super();
        this.from = from;
        this.ad = ad;
    }

    public String getFrom() {
        return from;
    }

    public LanternKscopeAdvertisement getAd() {
        return ad;
    }
}