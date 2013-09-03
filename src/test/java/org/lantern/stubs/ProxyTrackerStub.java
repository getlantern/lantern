package org.lantern.stubs;

import java.net.InetSocketAddress;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;

import org.lantern.ProxyHolder;
import org.lantern.ProxyTracker;

public class ProxyTrackerStub implements ProxyTracker {

    @Override
    public void start() throws Exception {
    }

    @Override
    public void stop() {
    }

    @Override
    public void clear() {
    }

    @Override
    public void clearPeerProxySet() {
    }

    @Override
    public void addProxy(URI jid, String hostPort) {
    }

    @Override
    public void addProxy(URI jid, InetSocketAddress iae) {
    }

    @Override
    public void addJidProxy(URI jid) {
    }

    @Override
    public void removePeer(URI uri) {
    }

    @Override
    public boolean hasJidProxy(URI uri) {
        return false;
    }

    @Override
    public boolean hasProxy() {
        return false;
    }

    @Override
    public Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference() {
        return new ArrayList<ProxyHolder>();
    }

    @Override
    public ProxyHolder firstConnectedProxy() {
        return null;
    }

    @Override
    public void onCouldNotConnect(ProxyHolder proxyAddress) {
    }

    @Override
    public void onError(URI peerUri) {
    }

}
