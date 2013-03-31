package org.lantern.event;

import org.lantern.kscope.LanternKscopeAdvertisement;

public class KscopeAdEvent {

    private final LanternKscopeAdvertisement ad;

    public KscopeAdEvent(final LanternKscopeAdvertisement ad) {
        this.ad = ad;
    }

    public LanternKscopeAdvertisement getAd() {
        return ad;
    }

}
