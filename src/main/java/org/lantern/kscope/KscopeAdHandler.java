package org.lantern.kscope;


public interface KscopeAdHandler {

    void handleAd(LanternKscopeAdvertisement ad);

    void onBase64Cert(String uri, String cert);

}
