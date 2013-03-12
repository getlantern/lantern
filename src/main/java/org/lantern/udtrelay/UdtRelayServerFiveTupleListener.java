package org.lantern.udtrelay;

import org.lastbamboo.common.offer.answer.OfferAnswer;
import org.lastbamboo.common.offer.answer.OfferAnswerListener;
import org.littleshoot.util.FiveTuple;

public class UdtRelayServerFiveTupleListener 
    implements OfferAnswerListener<FiveTuple>{

    @Override
    public void onOfferAnswerFailed(final OfferAnswer offerAnswer) {
        
    }

    @Override
    public void onTcpSocket(final FiveTuple sock) {
        
    }

    @Override
    public void onUdpSocket(final FiveTuple sock) {
        
    }

}
