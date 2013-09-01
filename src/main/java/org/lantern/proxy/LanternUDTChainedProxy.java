package org.lantern.proxy;

import java.net.InetSocketAddress;

import org.lantern.LanternTrustStore;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.util.FiveTuple;

/**
 * {@link ChainedProxy} that communicates downstream over UDP from a specifi
 * local port and that uses {@link LanternTrustStore} for encryption and
 * authentication.
 */
public class LanternUDTChainedProxy extends LanternTCPChainedProxy {
    private InetSocketAddress localAddress;

    public LanternUDTChainedProxy(FiveTuple fiveTuple,
            LanternTrustStore trustStore) {
        super(fiveTuple, trustStore);
        this.localAddress = fiveTuple.getLocal();
    }

    @Override
    public InetSocketAddress getLocalAddress() {
        return localAddress;
    }

    @Override
    public TransportProtocol getTransportProtocol() {
        return TransportProtocol.UDT;
    }

}
