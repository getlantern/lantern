package org.lantern;

import javax.inject.Named;

import org.jboss.netty.channel.group.ChannelGroup;
import org.lantern.state.Model;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.maxmind.geoip.LookupService;

@Singleton @Named("trusted")
public class TrustedPeerProxyManager extends DefaultPeerProxyManager {

    @Inject
    public TrustedPeerProxyManager(final ChannelGroup channelGroup,
        final XmppHandler xmppHandler, final Stats stats,
        final LanternSocketsUtil socketsUtil, final Model model,
        final LookupService lookupService, final CertTracker certTracker) {
        super(false, channelGroup, xmppHandler, stats, socketsUtil, model, 
            lookupService, certTracker);
    }

}
