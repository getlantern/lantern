package org.lantern.ksope;

import org.jivesoftware.smack.packet.Message;
import org.kaleidoscope.TrustGraphAdvertisement;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.LanternHub;
import org.lantern.XmppHandler;

/**
 * Lantern's implementation of a Kaleidoscope trust graph node. 
 * 
 * See: http://kscope.news.cs.nyu.edu/pub/TR-2008-918.pdf
 */
public class LanternTrustGraphNode extends TrustGraphNode {

    public LanternTrustGraphNode() {}
    
    @Override
    public void sendAdvertisement(final TrustGraphAdvertisement message,
        final TrustGraphNodeId neighbor, final int ttl) {
        // We extract the JID of the peer and send the advertisement to them.
        final String id = neighbor.getNeighborId();
        final String payload = message.getPayload();
        
        final XmppHandler handler = LanternHub.xmppHandler();
        final Message msg = new Message();
        msg.setProperty("kscope", payload);
        msg.setTo(id);
        handler.getP2PClient().getXmppConnection().sendPacket(msg);
        //final Roster roster = LanternHub.xmppHandler().getRoster();
        
    }

}
