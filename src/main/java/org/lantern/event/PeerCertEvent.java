package org.lantern.event;

import java.net.URI;
import java.security.cert.Certificate;

public class PeerCertEvent {

    private final URI jid;
    private final Certificate cert;

    public PeerCertEvent(URI jid, Certificate cert) {
        super();
        this.jid = jid;
        this.cert = cert;
    }

    public URI getJid() {
        return jid;
    }

    public Certificate getCert() {
        return cert;
    }

}
