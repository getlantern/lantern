package org.lantern.kscope;

import java.net.URI;

/**
 * Class for processing kaleidoscope advertisements.
 */
public interface KscopeAdHandler {

    /**
     * Processes a kscope ad.
     *
     * @param jid Who the ad is from.
     * @param ad The ad itself.
     */
    void handleAd(String jid, LanternKscopeAdvertisement ad);

    /**
     * Tells the ad handler to process a certificate from a peer.
     * 
     * @param uri The URI of the peer.
     * @param cert The base 64 encoded certificate.
     */
    void onBase64Cert(URI uri, String cert);

}
