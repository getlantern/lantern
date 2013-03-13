package org.lantern.udtrelay;

import java.net.InetSocketAddress;

import org.lantern.LanternUtils;
import org.lastbamboo.common.offer.answer.OfferAnswer;
import org.lastbamboo.common.offer.answer.OfferAnswerListener;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class listens for incoming NAT-traversed five tuples (endpoint pairs
 * plus protocol) 
 */
public class UdtRelayServerFiveTupleListener 
    implements OfferAnswerListener<FiveTuple>{
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Override
    public void onOfferAnswerFailed(final OfferAnswer offerAnswer) {
        // We don't really care about this on the server side.
        log.debug("Offer/answer failed");
    }

    @Override
    public void onTcpSocket(final FiveTuple fiveTuple) {
        log.warn("Received TCP tuple here?");
    }

    @Override
    public void onUdpSocket(final FiveTuple sock) {
        log.info("Received inbound P2P UDT connection from: {}", sock);
        final InetSocketAddress local = sock.getLocal();
        final UdtRelayProxy proxy = 
            new UdtRelayProxy(local, 
                LanternUtils.PLAINTEXT_LOCALHOST_PROXY_PORT);
        
        try {
            proxy.run();
        } catch (final Exception e) {
            log.warn("Exception running UDT proxy?", e);
        }
    }
}
