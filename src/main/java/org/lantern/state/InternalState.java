package org.lantern.state;

import java.util.Collection;
import java.util.HashSet;

import org.lantern.Events;
import org.lantern.state.Settings.Mode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class InternalState {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Modal[] modalSeqGive = {
        Modal.inviteFriends, Modal.finished, Modal.none,
    };
    
    private final Modal[] modalSeqGet = {
        Modal.proxiedSites, Modal.systemProxy, Modal.inviteFriends, 
        Modal.finished, Modal.none,
    };
    
    private Collection<Modal> modalsCompleted = new HashSet<Modal>();

    private final Model model;

    /*
    private final boolean[] modalsCompleted = {
        false, false, false, false, false, false, false
    };
    
    private final int welcome = 0;
    private final int passwordCreate = 1;
    private final int authorize = 2;
    private final int proxiedSites = 3;
    private final int systemProxy = 4;
    private final int inviteFriends = 5;
    private final int finished = 6;
    */

    @Inject
    public InternalState(final Model model) {
        this.model = model;
        //Events.register(this);
    }
    
    /*
    @Subscribe
    public void onConnectivity(final GoogleTalkStateEvent event) {
        if (model.isSetupComplete()) {
            log.info("Ignoring connectivity state when setup is complete");
            return;
        }
        final GoogleTalkState state = event.getState();
        switch (state) {
        case LOGIN_FAILED:
            break;
        case connected:
            advanceModal(null);
            break;
        case connecting:
            break;
        case notConnected:
            break;
        default:
            break;
        
        }
    }
    */

    public void resetInternalState() {
        //Arrays.fill(modalsCompleted, false);
        modalsCompleted = new HashSet<Modal>();
    }
 
    public void advanceModal(final Modal backToIfNone) {
        final Modal[] seq;
        if (this.model.getSettings().getMode() == Mode.get) {
            seq = modalSeqGet;
        } else {
            seq = modalSeqGive;
        }
        Modal next = null;
        for (final Modal modal : seq) {
            if (!this.modalsCompleted.contains(modal)) {
                log.info("Got modal!! "+modal);
                next = modal;
                break;
            }
        }
        if (backToIfNone != null && next != null && next == Modal.none) {
            next = backToIfNone;
        }
        Events.syncModal(this.model, next);
    }

    public void setModalCompleted(final Modal modal) {
        this.modalsCompleted.add(modal);
    }
}
