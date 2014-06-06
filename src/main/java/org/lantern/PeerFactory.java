package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;

import javax.net.ssl.SSLSession;

import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;

public interface PeerFactory {
    /**
     * This is called when we successfully make an outgoing connection to a
     * peer.
     * 
     * @param fullJid
     *            The JID of the peer.
     * @param isa
     *            The remote address of the peer.
     * @param type
     *            The type of the peer.
     */
    void onOutgoingConnection(URI fullJid, InetSocketAddress isa, Type type);

    Peer addPeer(URI fullJid, Type type);

    /**
     * Get the peer corresponding to the given jid.
     * 
     * @param fullJid
     * @return
     */
    Peer peerForJid(URI fullJid);

    /**
     * Get the peer corresponding to the certificate in the given SSLSession.
     * 
     * @param sslSession
     * @return
     */
    Peer peerForSession(SSLSession sslSession);

    /**
     * Update geolocation info for a peer
     *
     * @param peer
     *        The peer to update geo data for
     * @param address
     *        The current peer address
     * @return
     */
    void updateGeoData(final Peer peer, final String address);

}
