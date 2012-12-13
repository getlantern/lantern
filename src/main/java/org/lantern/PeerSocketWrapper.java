package org.lantern;

import java.net.Socket;
import java.net.URI;

import org.apache.commons.lang.time.DateUtils;
import org.jboss.netty.channel.group.ChannelGroup;

public class PeerSocketWrapper implements PeerSocketData, ByteTracker {


    private static final int DATA_RATE_SECONDS = 1;
    
    private final Long connectionTime;
    
    private final TimeSeries1D upBytesPerSecond = 
        new TimeSeries1D(DateUtils.MILLIS_PER_SECOND, 
            DateUtils.MILLIS_PER_SECOND*(DATA_RATE_SECONDS+1));
    private final TimeSeries1D downBytesPerSecond = 
        new TimeSeries1D(DateUtils.MILLIS_PER_SECOND, 
            DateUtils.MILLIS_PER_SECOND*(DATA_RATE_SECONDS+1));
    
    /**
     * We only store the peer URI so we can create a new connection to the
     * peer when this one succeeds.
     */
    private final URI peerUri;
    private final HttpRequestProcessor requestProcessor;
    private final Socket sock;

    private final long startTime;

    private final Stats stats;
    
    private final boolean incoming;

    public PeerSocketWrapper(final URI peerUri, final long startTime, 
        final Socket sock, final boolean anon, final ChannelGroup channelGroup,
        final Stats stats, final LanternSocketsUtil socketsUtil, 
        final boolean incoming) {
        this.peerUri = peerUri;
        this.sock = sock;
        this.startTime = startTime;
        this.stats = stats;
        this.incoming = incoming;
        this.connectionTime = System.currentTimeMillis() - startTime;
        if (anon) {
            this.requestProcessor = 
                new PeerHttpConnectRequestProcessor(sock, channelGroup, this, 
                    socketsUtil);
        } else {
            this.requestProcessor = 
                new PeerChannelHttpRequestProcessor(sock, channelGroup, this);
                //new PeerHttpRequestProcessor(sock);
        }
    }

    public Socket getSocket() {
        return sock;
    }

    public Long getConnectionTime() {
        return connectionTime;
    }

    public long getStartTime() {
        return startTime;
    }

    public URI getPeerUri() {
        return peerUri;
    }

    public HttpRequestProcessor getRequestProcessor() {
        return requestProcessor;
    }
    
    @Override
    public long getBpsUp() {
        return StatsTracker.getBytesPerSecond(upBytesPerSecond);
    }

    @Override
    public long getBpsDn() {
        return StatsTracker.getBytesPerSecond(downBytesPerSecond);
    }

    @Override
    public long getBpsTotal() {
        return getBpsUp() + getBpsDn();
    }

    @Override
    public long getBytesUp() {
        return this.upBytesPerSecond.lifetimeTotal();
    }

    @Override
    public long getBytesDn() {
        return this.downBytesPerSecond.lifetimeTotal();
    }

    @Override
    public long getBytesTotal() {
        return getBytesUp() + getBytesDn();
    }

    @Override
    public void addUpBytes(final long bytes) {
        this.upBytesPerSecond.addData(bytes);
        this.stats.addUpBytesToPeers(bytes);
    }

    @Override
    public void addDownBytes(final long bytes) {
        this.downBytesPerSecond.addData(bytes);
        this.stats.addDownBytesFromPeers(bytes);
    }

    public boolean isIncoming() {
        return incoming;
    }
}
