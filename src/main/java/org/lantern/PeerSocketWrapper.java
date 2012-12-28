package org.lantern;

import java.net.Socket;
import java.net.URI;

import org.apache.commons.lang.time.DateUtils;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.jboss.netty.channel.group.ChannelGroup;
import org.lantern.state.Model.Run;

import com.google.common.base.Preconditions;

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

    public PeerSocketWrapper(final URI peerUri, 
        final long startTime, final Socket sock, final boolean anon, 
        final ChannelGroup channelGroup, final Stats stats, 
        final LanternSocketsUtil socketsUtil, 
        final boolean incoming) {
        Preconditions.checkNotNull(peerUri, "Null peer URI?");
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

    @JsonIgnore
    public Socket getSocket() {
        return sock;
    }

    @JsonView({Run.class})
    public Long getConnectionTime() {
        return connectionTime;
    }

    @JsonView({Run.class})
    public long getStartTime() {
        return startTime;
    }

    @JsonView({Run.class})
    public URI getPeerUri() {
        return peerUri;
    }

    @JsonIgnore
    public HttpRequestProcessor getRequestProcessor() {
        return requestProcessor;
    }
    
    @Override
    @JsonView({Run.class})
    public long getBpsUp() {
        return StatsTracker.getBytesPerSecond(upBytesPerSecond);
    }

    @Override
    @JsonView({Run.class})
    public long getBpsDn() {
        return StatsTracker.getBytesPerSecond(downBytesPerSecond);
    }

    @Override
    @JsonView({Run.class})
    public long getBpsTotal() {
        return getBpsUp() + getBpsDn();
    }

    @Override
    @JsonView({Run.class})
    public long getBytesUp() {
        return this.upBytesPerSecond.lifetimeTotal();
    }

    @Override
    @JsonView({Run.class})
    public long getBytesDn() {
        return this.downBytesPerSecond.lifetimeTotal();
    }

    @Override
    @JsonView({Run.class})
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

    @JsonView({Run.class})
    public boolean isIncoming() {
        return incoming;
    }
}
