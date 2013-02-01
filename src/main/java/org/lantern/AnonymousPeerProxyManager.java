package org.lantern;

import javax.inject.Named;

import org.jboss.netty.channel.group.ChannelGroup;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.maxmind.geoip.LookupService;

@Singleton @Named("anon")
public class AnonymousPeerProxyManager extends DefaultPeerProxyManager {

    @Inject
    public AnonymousPeerProxyManager(final ChannelGroup channelGroup,
        final XmppHandler xmppHandler, final Stats stats,
        final LanternSocketsUtil socketsUtil, final Model model,
        final LookupService lookupService, final CertTracker certTracker,
        final ModelUtils modelUtils) {
        super(true, channelGroup, xmppHandler, stats, socketsUtil, model, 
            lookupService, certTracker, modelUtils);
    }

}
