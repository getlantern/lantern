package org.lantern.state;

import java.util.Timer;
import java.util.TimerTask;

import org.cometd.annotation.Configure;
import org.cometd.annotation.Listener;
import org.cometd.annotation.Service;
import org.cometd.annotation.Session;
import org.cometd.bayeux.Channel;
import org.cometd.bayeux.Message;
import org.cometd.bayeux.server.ConfigurableServerChannel;
import org.cometd.bayeux.server.ServerSession;
import org.lantern.LanternClientConstants;
import org.lantern.LanternService;
import org.lantern.event.ClosedBetaEvent;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.lantern.event.SyncType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Service for pushing updated Lantern state to the client.
 */
@Service("sync")
@Singleton
public class SyncService implements LanternService {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Session
    private ServerSession session;

    private final SyncStrategy strategy;

    private final Model model;

    private final Timer timer;

    /**
     * Creates a new sync service.
     *
     * @param strategy The strategy to use for syncing
     * @param model The model to use.
     */
    @Inject
    public SyncService(final SyncStrategy strategy,
        final Model model, final Timer timer) {
        this.strategy = strategy;
        this.model = model;
        this.timer = timer;
        // Make sure the config class is added as a listener before this class.
        Events.register(this);
    }


    @Override
    public void start() {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                //sync();
                delegateSync(SyncType.ADD, SyncPath.PEERS, 
                    model.getPeers());
            }
        }, 3000, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
    }

    @Override
    public void stop() {
        this.timer.cancel();
    }

    @Configure("/service/sync")
    private void configureSync(final ConfigurableServerChannel channel) {
        channel.setPersistent(true);
    }

    //@Listener(Channel.META_CONNECT)
    @Listener(Channel.META_SUBSCRIBE)
    public void metaConnect(final ServerSession remote, final Message connect) {
        // Make sure we give clients the most recent data whenever they connect.
        log.debug("Got connection from client, calling sync");

        final Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                log.info("Syncing with frontend...");
                delegateSync(SyncPath.ALL, model);
            }

        }, "CometD-Sync-OnConnect-Thread");
        t.setDaemon(true);
        t.start();
    }

    @Subscribe
    public void onSync(final SyncEvent syncEvent) {
        log.debug("Got sync event");
        // We want to force a sync here regardless of whether or not we've
        // recently synced.
        //sync(true, syncEvent.getChannel());
        delegateSync(syncEvent.getOp(), syncEvent.getPath(), syncEvent.getValue());
    }

    @Subscribe
    public void closedBeta(final ClosedBetaEvent betaEvent) {
        final boolean alreadyInvited = this.model.getConnectivity().isInvited();

        final boolean invited = betaEvent.isInClosedBeta();
        if (alreadyInvited == invited) {
            log.debug("No change in invited state");
            return;
        }
        // Note this is the only place setInvited should be called. We do all
        // checks here to know whether or not to sync with the frontend and
        // because of the use of ClosedBetaEvent for thread syncing in
        // the xmpp handler.
        this.model.getConnectivity().setInvited(invited);

        delegateSync(SyncPath.INVITED, invited);
    }


    private void delegateSync(final SyncType type, final SyncPath path,
            final Object value) {
        delegateSync(type, path.getPath(), value);
    }
    
    private void delegateSync(final SyncPath path, final Object value) {
        delegateSync(SyncType.ADD, path.getPath(), value);
    }

    private void delegateSync(final SyncType syncType, final String path, 
        final Object value) {
        this.strategy.sync(this.session, syncType, path, value);
    }
}
