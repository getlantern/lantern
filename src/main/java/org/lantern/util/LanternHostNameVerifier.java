package org.lantern.util;

import javax.net.ssl.SSLException;

import org.apache.http.annotation.Immutable;
import org.apache.http.conn.ssl.AbstractVerifier;
import org.lantern.LanternUtils;

@Immutable
public class LanternHostNameVerifier extends AbstractVerifier {

    @Override
    public final void verify(
        final String host,
        final String[] cns,
        final String[] subjectAlts) throws SSLException {
        if (!host.equals(LanternUtils.getFallbackServerHost())) {
            super.verify(host, cns, subjectAlts, true);
        }
    }

    @Override
    public final String toString() {
        return "LANTERN VERIFIER";
    }

}

