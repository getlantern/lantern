package org.lantern.kscope;


public interface KscopeAdHandler {

    boolean handleAd(String from, LanternKscopeAdvertisement ad);

    void onBase64Cert(String uri, String cert);

}
