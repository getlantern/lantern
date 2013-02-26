package org.lantern;

import org.lantern.kscope.LanternKscopeAdvertisement;

public interface KscopeAdHandler {

    void handleAd(LanternKscopeAdvertisement ad);

    void onBase64Cert(String uri, String cert);

}
