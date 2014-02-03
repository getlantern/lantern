package org.lantern.stubs;

import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;

import org.lantern.proxy.ProxyHolder;
import org.lantern.proxy.ProxyInfo;
import org.lantern.proxy.ProxyTracker;

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
    public void addProxy(ProxyInfo info) {
    }

    @Override
    public void removeNattedProxy(URI uri) {
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
    public ProxyHolder firstConnectedTcpProxy() {
        return null;
    }

    @Override
    public void onCouldNotConnect(ProxyHolder proxyAddress) {
    }

    @Override
    public void onError(URI peerUri) {
    }

}
