package org.lantern.udtrelay;

import java.net.InetSocketAddress;

import org.lantern.LanternUtils;
import org.lastbamboo.common.offer.answer.OfferAnswer;
import org.lastbamboo.common.offer.answer.OfferAnswerListener;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayServerFiveTupleListener 
    implements OfferAnswerListener<FiveTuple>{
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Override
    public void onOfferAnswerFailed(final OfferAnswer offerAnswer) {
        
    }

    @Override
    public void onTcpSocket(final FiveTuple sock) {
        
    }

    @Override
    public void onUdpSocket(final FiveTuple sock) {
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
