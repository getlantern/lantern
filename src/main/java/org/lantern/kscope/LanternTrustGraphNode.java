package org.lantern.kscope;

import org.jivesoftware.smack.packet.Message;
import org.kaleidoscope.TrustGraphAdvertisement;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.JsonUtils;
import org.lantern.LanternConstants;
import org.lantern.event.Events;
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

    private static final int IDEAL_REACH      = 80; // aka "r"
    private static final int MAX_ROUTE_LENGTH =  4; // aka "w_max"
    private static final int MIN_ROUTE_LENGTH =   2; // aka "w_min"

    @Override
    public void advertiseSelf(TrustGraphAdvertisement message) {
        super.advertiseSelf(message);
    }
    
    @Override
    public void sendAdvertisement(final TrustGraphAdvertisement message,
        final TrustGraphNodeId neighbor, final int ttl) {
        // We extract the JID of the peer and send the advertisement to them.
        final String id = neighbor.getNeighborId();
        String payload = message.getPayload();

        try {
            LanternKscopeAdvertisement ad = JsonUtils.OBJECT_MAPPER.readValue(
                payload, LanternKscopeAdvertisement.class
            );
            ad.setTtl(ttl);

            payload = JsonUtils.jsonify(ad);
        } catch(Exception e) {
            log.error("could not update ttl for kscope ad to {}", neighbor);
            return;
        }
        
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            LanternConstants.KSCOPE_ADVERTISEMENT);
        msg.setProperty(LanternConstants.KSCOPE_ADVERTISEMENT_KEY, payload);
        msg.setTo(id);
        log.debug("Sending kscope ad to {}.", id);
        log.debug("-- Payload: {}", payload);
        Events.asyncEventBus().post(msg);
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
