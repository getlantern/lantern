package org.lantern.stubs;

import java.net.InetSocketAddress;
import java.net.URI;

import org.lantern.ProxyHolder;
import org.lantern.ProxyQueue;
import org.lantern.ProxyTracker;

public class ProxyTrackerStub implements ProxyTracker {

    @Override
    public void onCouldNotConnect(ProxyHolder proxyAddress) {
    }

    @Override
    public void onCouldNotConnectToPeer(URI peerUri) {
    }

    @Override
    public void onError(URI peerUri) {
    }

    @Override
    public void onCouldNotConnectToLae(ProxyHolder proxyAddress) {
    }

    @Override
    public ProxyHolder getLaeProxy() {
        return null;
    }

    @Override
    public ProxyHolder getProxy() {
        return null;
    }

    @Override
    public ProxyHolder getJidProxy() {
        return null;
    }

    @Override
    public boolean hasProxy() {
        return false;
    }

    @Override
    public void start() throws Exception {
    }

    @Override
    public void stop() {
    }

    @Override
    public boolean isEmpty() {
        return false;
    }

    @Override
    public void clear() {
    }

    @Override
    public void clearPeerProxySet() {
    }

    @Override
    public void addLaeProxy(String cur) {
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
    public void setSuccess(ProxyHolder proxyHolder) {}

    @Override
    public void addProxyWithChecks(URI jid, ProxyQueue proxyQueue,
            ProxyHolder proxy) {}

}
