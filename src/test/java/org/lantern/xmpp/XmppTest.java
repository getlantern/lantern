package org.lantern.xmpp;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.SASLAuthentication;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Message;

public class XmppTest {
    public static void main(String[] args) throws Exception {
        ConnectionConfiguration cc = new ConnectionConfiguration("127.0.0.1",
                5222);
        SASLAuthentication.supportSASLMechanism("EXTERNAL", 0);
        XMPPConnection conn = new XMPPConnection(cc);
        conn.connect();
        Message message = new Message("test1@getlantern.org");
        message.setBody("Hello World");
        conn.sendPacket(message);
    }
}
