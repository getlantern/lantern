package org.lantern.http;

import java.io.IOException;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.state.InternalState;
import org.lantern.state.Modal;
import org.lantern.state.Model;
import org.lantern.state.ModelChangeImplementor;
import org.lantern.state.Settings.Mode;
import org.lantern.state.SyncService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class InteractionServlet extends HttpServlet {

    private final InternalState internalState;
    
    private enum Interaction {
        get,
        give,
    }
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    /**
     * Generated serialization ID.
     */
    private static final long serialVersionUID = -8820179746803371322L;

    private final ModelChangeImplementor changeImplementor;

    private final Model model;

    private final SyncService syncService;
    
    public InteractionServlet(final ModelChangeImplementor changeImplementor,
        final SyncService syncService) {
        this.changeImplementor = changeImplementor;
        this.syncService = syncService;
        this.model = changeImplementor.getModel();
        this.internalState = new InternalState(this.model);
    }
    
    @Override
    protected void doGet(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException, 
        IOException {
        processRequest(req, resp);
    }
    @Override
    protected void doPost(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException, 
        IOException {
        processRequest(req, resp);
    }
    
    protected void processRequest(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final String uri = req.getRequestURI();
        log.info("Received URI: {}", uri);
        final Map<String, String> params = HttpUtils.toParamMap(req);
        log.info("Params: {}", params);
        final String interactionStr = params.get("interaction");
        if (StringUtils.isBlank(interactionStr)) {
            log.info("No interaction!!");
            HttpUtils.sendClientError(resp, "interaction argument required!");
            return;
        }
        
        final Interaction inter = Interaction.valueOf(interactionStr);
        
        final Modal modal = this.model.getModal();
        switch (modal) {
        case welcome:
            switch (inter) {
            case get:
                log.info("Setting get mode");
                handleGiveGet(true);
                this.changeImplementor.setGetMode(true);
                break;
            case give:
                log.info("Setting give mode");
                handleGiveGet(false);
                break;
            default:
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case about:
            break;
        case authorize:
            break;
        case finished:
            break;
        case firstInviteReceived:
            break;
        case gtalkUnreachable:
            break;
        case inviteFriends:
            break;
        case none:
            break;
        case notInvited:
            break;
        case proxiedSites:
            break;
        case requestInvite:
            break;
        case requestSent:
            break;
        case settings:
            break;
        case settingsLoadFailure:
            break;
        case systemProxy:
            break;
        case updateAvailable:
            break;
        case authorizeLater:
            break;
        case confirmReset:
            break;
        case contactDevs:
            break;
        case giveModeForbidden:
            break;
        case passwordCreate:
            break;
        default:
            log.info("No matching modal for {}", modal);
        }
    }

    private void handleGiveGet(final boolean getMode) {
        this.model.getSettings().setMode(getMode ? Mode.get : Mode.give);
        this.model.setModal(SystemUtils.IS_OS_LINUX ? Modal.passwordCreate : Modal.authorize);
        //this.syncService.publishSync("", this.model.getSettings().getMode());
        this.syncService.publishSync("settings.mode", this.model.getSettings().getMode());
        this.syncService.publishSync("modal", this.model.getModal());
        this.internalState.setModalCompleted(Modal.welcome);
        this.changeImplementor.setGetMode(getMode);
    }

}
