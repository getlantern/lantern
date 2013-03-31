package org.lantern.kscope;

import java.net.URI;


public interface KscopeAdHandler {

    boolean handleAd(URI from, LanternKscopeAdvertisement ad);

    void onBase64Cert(URI uri, String cert);

}
