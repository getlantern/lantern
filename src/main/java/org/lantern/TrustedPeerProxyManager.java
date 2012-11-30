package org.lantern;

import javax.inject.Named;

import org.jboss.netty.channel.group.ChannelGroup;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton @Named("trusted")
public class TrustedPeerProxyManager extends DefaultPeerProxyManager {

    @Inject
    public TrustedPeerProxyManager(final ChannelGroup channelGroup,
        final XmppHandler xmppHandler, final Stats stats,
        final LanternSocketsUtil socketsUtil) {
        super(false, channelGroup, xmppHandler, stats, socketsUtil);
    }

}
