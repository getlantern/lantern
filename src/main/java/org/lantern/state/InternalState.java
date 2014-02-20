package org.lantern.state;

import static org.lantern.Tr.*;

import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;

import org.apache.commons.lang.SystemUtils;
import org.lantern.MessageKey;
import org.lantern.Messages;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class InternalState {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private Modal lastModal;

    private final Modal[] modalSeq = {
        Modal.authorize, Modal.lanternFriends, Modal.proxiedSites,
        Modal.finished, Modal.none,
    };

    private final Collection<Modal> modalsCompleted = new HashSet<Modal>();

    private final Model model;

    private boolean notInvited = false;

    private final Messages msgs;

    public Modal getLastModal() {
        return this.lastModal;
    }

    public void setLastModal(final Modal lastModal) {
        this.lastModal = lastModal;
    }

    @Inject
    public InternalState(final Model model, final Messages msgs) {
        this.model = model;
        this.msgs = msgs;
        Events.register(this);
    }

    public void advanceModal(final Modal backToIfNone) {
        Modal next = null;
        for (final Modal modal : modalSeq) {
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
            if (!model.isWelcomeMessageShown()) {
                model.setWelcomeMessageShown(true);
                final MessageKey iconLoc;
                if (SystemUtils.IS_OS_MAC_OSX || SystemUtils.IS_OS_LINUX) {
                    iconLoc = MessageKey.ICONLOC_MENUBAR;
                } else if (SystemUtils.IS_OS_WINDOWS) {
                    iconLoc = MessageKey.ICONLOC_SYSTRAY;
                } else {
                    log.warn("unsupported OS");
                    iconLoc = MessageKey.ICONLOC_UNKNOWN;
                }
                this.msgs.info(MessageKey.SETUP, tr(iconLoc));
            }
        }
        Events.syncModal(this.model, next);
    }

    public void setCompletedTo(final Modal stopAt) {
        if(!Arrays.asList(modalSeq).contains(stopAt)) return;
        for (final Modal modal : modalSeq) {
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
        setNotInvited(false);
    }

	public boolean isNotInvited() {
		return notInvited;
	}

	public void setNotInvited(boolean notInvited) {
		this.notInvited = notInvited;
	}
}
