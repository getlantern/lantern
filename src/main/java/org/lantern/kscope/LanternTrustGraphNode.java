package org.lantern.kscope;

import org.codehaus.jackson.map.ObjectMapper;
import org.jivesoftware.smack.packet.Message;
import org.kaleidoscope.TrustGraphAdvertisement;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.lantern.kscope.LanternTrustGraphNode;
import org.lantern.JsonUtils;
import org.lantern.LanternConstants;
import org.lantern.XmppHandler;
import org.lastbamboo.common.p2p.P2PConstants;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Lantern's implementation of a Kaleidoscope trust graph node. 
 * 
 * See: http://kscope.news.cs.nyu.edu/pub/TR-2008-918.pdf
 */
public class LanternTrustGraphNode extends TrustGraphNode {
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    public static final int IDEAL_REACH      = 500; // aka "r"
    public static final int MAX_ROUTE_LENGTH =  10; // aka "w_max"
    public static final int MIN_ROUTE_LENGTH =   7; // aka "w_min"

    private final XmppHandler handler;

    public LanternTrustGraphNode(final XmppHandler handler) {
        this.handler = handler;
    }
    
    @Override
    public void sendAdvertisement(final TrustGraphAdvertisement message,
        final TrustGraphNodeId neighbor, final int ttl) {
        // We extract the JID of the peer and send the advertisement to them.
        final String id = neighbor.getNeighborId();
        String payload = message.getPayload();

        ObjectMapper mapper = new ObjectMapper();
        try {
            LanternKscopeAdvertisement ad = mapper.readValue(
                payload, LanternKscopeAdvertisement.class
            );
            ad.setTtl(ttl);

            payload = JsonUtils.jsonify(ad);
        } catch(Exception e) {
            log.error("could not update ttl for kscope ad to {}", neighbor);
        }
        
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            LanternConstants.KSCOPE_ADVERTISEMENT);
        msg.setProperty(LanternConstants.KSCOPE_ADVERTISEMENT_KEY, payload);
        msg.setTo(id);
        log.debug("Sending kscope ad to {}.", id);
        log.debug("-- Payload: {}", payload);
        handler.getP2PClient().getXmppConnection().sendPacket(msg);
    }

    @Override
    public int getMinRouteLength() {
        return MIN_ROUTE_LENGTH;
    }

    @Override
    public int getMaxRouteLength() {
        return MAX_ROUTE_LENGTH;
    }

    @Override
    public int getIdealReach() {
        return IDEAL_REACH;
    }

}
