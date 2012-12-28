package org.lantern;

/**
 * Class for keeping track of certificates associated with specific full JIDs 
 * of peers. Note these are the full IDS of logged in instances, not simply
 * the JIDs associated with users.
 * 
 * This extra mapping is necessary because we cannot exchange certs through
 * the normal offer/answer exchange because the answerer may attempt to 
 * connect to the offerer before the offerer has access to the answerers cert
 * (i.e. before the offerer has received the answer). This requires us to
 * make the cert exchange prior to the offer/answer exchange, although that
 * also allows the exchange of certs only one time with peers.
 */
public interface CertTracker {

    /**
     * Adds the specified certificate for the specified full JID.
     * 
     * @param base64Cert The base 64 encoded cert.
     * @param fullJid The full JID of the peer.
     */
    void addCert(String base64Cert, String fullJid);

    /**
     * Accessor for the cert associated with the specified JID.
     * 
     * @param fullJid The full JID for the peer.
     * @return The cert.
     */
    String getCertForJid(String fullJid);
}
