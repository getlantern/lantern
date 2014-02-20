package org.lantern.proxy;

import java.net.Socket;

import org.lantern.state.Model;
import org.lastbamboo.common.offer.answer.OfferAnswer;
import org.lastbamboo.common.offer.answer.OfferAnswerListener;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class listens for incoming NAT-traversed five tuples (endpoint pairs
 * plus protocol)
 */
@Singleton
public class UdtServerFiveTupleListener
        implements OfferAnswerListener<FiveTuple> {

    private static final Logger log = LoggerFactory
            .getLogger(UdtServerFiveTupleListener.class);

    private final GiveModeProxy giveModeProxy;
    private final Model model;

    @Inject
    public UdtServerFiveTupleListener(GiveModeProxy giveModeProxy,
            Model model) {
        this.giveModeProxy = giveModeProxy;
        this.model = model;
    }

    /**
     * We don't really care about this on the server side.
     */
    @Override
    public void onOfferAnswerFailed(final OfferAnswer offerAnswer) {
        log.debug("Offer/answer failed");
    }

    /**
     * <p>
     * Whenever we learn about a new traversed UDP {@link FiveTuple}, we clone
     * the existing {@link GiveModeProxy} and tell the clone to listen on the
     * local address of that five tuple.
     * </p>
     */
    @Override
    public void onUdpSocket(final FiveTuple sock) {
        log.info("Received inbound P2P UDT connection from: {}", sock);
        giveModeProxy.getServer().clone()
                .withTransportProtocol(TransportProtocol.UDT)
                .withAddress(sock.getLocal())
                .start();
        log.info("Now listening for UDT traffic at: {}", sock.getLocal());
        // note - we don't need to hang on to the clone because it will
        // get shut down automatically when the giveModeProxy gets shut
        // down.
    }

    @Override
    public void onTcpSocket(final Socket socket) {
        final String msg =
                "Unexpectedly received TCP socket for UDT relay server: {}";
        log.error(msg, ThreadUtils.dumpStack());
        throw new Error(msg);
    }
}
