package org.lantern.util;

import javax.net.ssl.SSLException;

import org.apache.http.HttpHost;
import org.apache.http.annotation.Immutable;
import org.apache.http.conn.ssl.AbstractVerifier;

@Immutable
public class LanternHostNameVerifier extends AbstractVerifier {

    private final HttpHost proxy;

    public LanternHostNameVerifier(final HttpHost proxy) {
        this.proxy = proxy;
    }
    
    @Override
    public final void verify(
        final String host,
        final String[] cns,
        final String[] subjectAlts) throws SSLException {
        if (proxy == null) {
            super.verify(host, cns, subjectAlts, true);
        }
        if (!host.equals(proxy.getHostName())) {
            super.verify(host, cns, subjectAlts, true);
        }
    }

    @Override
    public final String toString() {
        return "LANTERN VERIFIER";
    }

}

