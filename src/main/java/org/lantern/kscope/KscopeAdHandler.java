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
     * @return <code>true</code> if this was a newly processed ad, otherwise
     * <code>false</code> if we've seen this ad before.
     */
    boolean handleAd(String jid, LanternKscopeAdvertisement ad);

    /**
     * Tells the ad handler to process a certificate from a peer.
     * 
     * @param uri The URI of the peer.
     * @param cert The base 64 encoded certificate.
     */
    void onBase64Cert(URI uri, String cert);

}
