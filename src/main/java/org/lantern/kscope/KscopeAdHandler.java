package org.lantern.kscope;


public interface KscopeAdHandler {

    void handleAd(String from, LanternKscopeAdvertisement ad);

    void onBase64Cert(String uri, String cert);

}
