package org.mg.server;

import java.io.IOException;

import org.jivesoftware.smack.XMPPException;

public interface XmppProxy {

    void start() throws XMPPException, IOException;

}
