package org.lantern.util;

import javax.net.ssl.SSLException;

import org.apache.http.HttpHost;
import org.apache.http.annotation.Immutable;
import org.apache.http.conn.ssl.AbstractVerifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Immutable
public class LanternHostNameVerifier extends AbstractVerifier {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final HttpHost proxy;

    public LanternHostNameVerifier(final HttpHost proxy) {
        this.proxy = proxy;
    }
    
    @Override
    public final void verify(
        final String host,
        final String[] cns,
        final String[] subjectAlts) throws SSLException {
        if (this.proxy == null) {
            super.verify(host, cns, subjectAlts, true);
            return;
        }
        log.debug("Proxy: {}", proxy);
        if (!host.equals(proxy.getHostName())) {
            super.verify(host, cns, subjectAlts, true);
        }
    }

    @Override
    public final String toString() {
        return "LANTERN VERIFIER";
    }

}

