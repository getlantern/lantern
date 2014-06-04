package org.lantern.stubs;

import java.net.InetSocketAddress;
import java.net.URI;
import java.util.HashMap;
import java.util.Map;

import javax.net.ssl.SSLSession;

import org.lantern.PeerFactory;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;

public class PeerFactoryStub implements PeerFactory {
    private Map<URI, Peer> peersByJid = new HashMap<URI, Peer>();

    @Override
    public void onOutgoingConnection(URI fullJid, InetSocketAddress isa,
            Type type) {
    }

    @Override
    public Peer addPeer(URI fullJid, Type type) {
        return null;
    }

    @Override
    public void updateGeoData(final Peer peer, final String address) {

    }

    @Override
    synchronized public Peer peerForJid(URI fullJid) {
        Peer peer = peersByJid.get(fullJid);
        if (peer == null) {
            peer = new Peer();
            peersByJid.put(fullJid, peer);
        }
        return peer;
    }

    @Override
    synchronized public Peer peerForSession(SSLSession sslSession) {
        return null;
    }

}
