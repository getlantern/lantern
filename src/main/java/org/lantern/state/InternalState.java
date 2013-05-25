package org.lantern.state;

import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;

import org.apache.commons.lang.SystemUtils;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.state.Notification.MessageType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class InternalState {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private Modal lastModal;

    private final Modal[] modalSeqGive = {
        Modal.authorize, Modal.lanternFriends, Modal.finished, Modal.none,
    };
    
    private final Modal[] modalSeqGet = {
        Modal.authorize, Modal.lanternFriends, Modal.proxiedSites,
        Modal.finished, Modal.none,
    };
    
    private Collection<Modal> modalsCompleted = new HashSet<Modal>();

    private final Model model;

    public Modal getLastModal() {
        return this.lastModal;
    }

    public void setLastModal(final Modal lastModal) {
        this.lastModal = lastModal;
    }

    @Inject
    public InternalState(final Model model) {
        this.model = model;
        Events.register(this);
    }
 
    public void advanceModal(final Modal backToIfNone) {
        final Modal[] seq;
        if (this.model.getSettings().getMode() == Mode.get) {
            seq = modalSeqGet;
        } else if(this.model.getSettings().getMode() == Mode.give) {
            seq = modalSeqGive;
        } else {
            Events.syncModal(this.model, Modal.welcome);
            return;
        }
        Modal next = null;
        for (final Modal modal : seq) {
            if (!this.modalsCompleted.contains(modal)) {
                log.info("Got modal!! ({})", modal);
                next = modal;
                break;
            }
        }
        log.debug("next modal: {}", next);
        if (backToIfNone != null && next != null && next == Modal.none) {
            next = backToIfNone;
        }
        if (next == Modal.none) {
            this.model.setSetupComplete(true);
            Events.sync(SyncPath.SETUPCOMPLETE, true);

            final String iconLoc;
            if (SystemUtils.IS_OS_MAC_OSX || SystemUtils.IS_OS_LINUX) {
                iconLoc = "menu bar at the top of the screen";
            } else if (SystemUtils.IS_OS_WINDOWS) {
                iconLoc = "system tray at the bottom right of your screen";
            } else {
                log.warn("unsupported OS");
                iconLoc = "(unsupported OS: Lantern icon may not be visible)";
            }
            final String msg = "Now that you're all set up, take a minute to "+
                "explore the Lantern global network map, or just get back to "+
                "whatever you'd like to do next. You can always get back here "+
                "through the Lantern icon in your "+iconLoc+".";
            model.addNotification(msg, MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
        }
        Events.syncModal(this.model, next);
    }

    public void setCompletedTo(final Modal stopAt) {
        final Modal[] seq;
        if (this.model.getSettings().getMode() == Mode.get) {
            seq = modalSeqGet;
        } else {
            seq = modalSeqGive;
        }
        if(!Arrays.asList(seq).contains(stopAt)) return;
        for (final Modal modal : seq) {
            if(modal == stopAt) break;
            if (!this.modalsCompleted.contains(modal)) {
                setModalCompleted(modal);
            }
        }
        return;
    }

    public void setModalCompleted(final Modal modal) {
        this.modalsCompleted.add(modal);
    }
    
    @Subscribe
    public void onReset(final ResetEvent re) {
        modalsCompleted.clear();
    }
}
