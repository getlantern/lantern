package org.lantern.event;

import java.net.URI;

public class PeerCertEvent {

    private final URI jid;
    private final String base64Cert;

    public PeerCertEvent(final URI jid, final String base64Cert) {
        this.jid = jid;
        this.base64Cert = base64Cert;
    }

    public URI getJid() {
        return jid;
    }

    public String getBase64Cert() {
        return base64Cert;
    }

}
