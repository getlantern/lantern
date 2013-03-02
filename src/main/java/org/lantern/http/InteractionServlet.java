package org.lantern.http;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.JsonUtils;
import org.lantern.LanternClientConstants;
import org.lantern.XmppHandler;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.event.SetupCompleteEvent;
import org.lantern.event.SyncEvent;
import org.lantern.state.InternalState;
import org.lantern.state.JsonModelModifier;
import org.lantern.state.Modal;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelService;
import org.lantern.state.Settings.Mode;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class InteractionServlet extends HttpServlet {

    private final InternalState internalState;

    private enum Interaction {
        GET,
        GIVE,
        INVITE,
        CONTINUE,
        SETTINGS,
        CLOSE,
        RESET,
        SET,
        PROXIEDSITES,
        CANCEL,
        LANTERNFRIENDS,
        RETRY,
        REQUESTINVITE,
        CONTACT,
        ABOUT,
        ACCEPT,
        DECLINE
    }

    private final Logger log = LoggerFactory.getLogger(getClass());

    /**
     * Generated serialization ID.
     */
    private static final long serialVersionUID = -8820179746803371322L;

    private final ModelService modelService;

    private final Model model;

    private final ModelIo modelIo;

    private final XmppHandler xmppHandler;

    @Inject
    public InteractionServlet(final Model model,
        final ModelService modelService,
        final InternalState internalState,
        final ModelIo modelIo, final XmppHandler xmppHandler) {
        this.model = model;
        this.modelService = modelService;
        this.internalState = internalState;
        this.modelIo = modelIo;
        this.xmppHandler = xmppHandler;
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
        log.debug("Received URI: {}", uri);
        final Map<String, String> params = HttpUtils.toParamMap(req);
        log.debug("Params: {}", params);
        final String interactionStr = StringUtils.substringAfterLast(uri, "/");//params.get("interaction");
        if (StringUtils.isBlank(interactionStr)) {
            log.debug("No interaction!!");
            HttpUtils.sendClientError(resp, "interaction argument required!");
            return;
        }

        log.debug("Headers: "+HttpUtils.getRequestHeaders(req));

        final int cl = req.getContentLength();
        String json = "";
        if (cl > 0) {
            try {
                json = IOUtils.toString(req.getInputStream());
            } catch (final IOException e) {
                log.error("Could not parse json?");
            }
        }

        log.debug("Body: '"+json+"'");

        final Interaction inter =
            Interaction.valueOf(interactionStr.toUpperCase());

        if (inter == Interaction.CLOSE) {
            handleClose(json);
        }

        final Modal modal = this.model.getModal();

        switch (modal) {
        case welcome:
            switch (inter) {
            case GET:
                log.debug("Setting get mode");
                handleSetModeWelcome(Mode.get);
                break;
            case GIVE:
                log.debug("Setting give mode");
                handleSetModeWelcome(Mode.give);
                break;
            default:
                log.error("Did not handle interaction for modal {} with " +
                        "params: {}", modal, params);
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case about:
            if (handleModeSwitch(inter)) {
                break;
            }
            this.internalState.setModalCompleted(Modal.finished);
            this.internalState.advanceModal(null);
            Events.syncModel(this.model);
            break;
        case authorize:
            log.error("Processing authorize modal...");
            break;
        case finished:
            switch (inter) {
            case CONTINUE:
                log.debug("Processing continue");
                this.model.setShowVis(true);
                this.model.setSetupComplete(true);

                // Things like configuring the system proxy rely on setup being
                // complete, so propagate the event.
                Events.asyncEventBus().post(new SetupCompleteEvent());
                this.internalState.setModalCompleted(Modal.finished);
                this.internalState.advanceModal(null);
                Events.syncModel(this.model);
                break;
            case SET:
                log.debug("Processing set in finished modal...applying JSON\n{}", json);
                applyJson(json);
                break;
            default:
                log.error("Did not handle interaction for modal {} with " +
                        "params: {}", modal, params);
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case firstInviteReceived:
            log.error("Processing invite received...");
            break;
        case gtalkUnreachable:
            log.error("Processing gtalk unreachable.");
            break;
        case lanternFriends:
            if (handleModeSwitch(inter)) {
                break;
            }
            switch (inter) {
            case INVITE:
                invite(json);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            case CONTINUE:
                log.debug("Processing continue for friends dialog");
                invite(json);
                this.internalState.setModalCompleted(Modal.lanternFriends);
                this.internalState.advanceModal(null);
                break;
            case PROXIEDSITES:
                log.debug("Processing proxiedSites in lanternFriends");
                Events.syncModal(model, Modal.proxiedSites);
                break;
            case SETTINGS:
                log.debug("Processing settings in lanternFriends");
                Events.syncModal(model, Modal.settings);
                break;
            case ACCEPT:
                acceptInvite(json);
                Events.syncModal(model, Modal.lanternFriends);
                break;

            case DECLINE:
                declineInvite(json);
                Events.syncModal(model, Modal.lanternFriends);
                break;
            default:
                log.error("Did not handle interaction for modal {} with " +
                        "params: {}", modal, params);
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case none:
            handleModeSwitch(inter);
            break;
        case notInvited:
            switch (inter) {
            case RETRY:
                Events.syncModal(model, Modal.authorize);
                break;
            case REQUESTINVITE:
                Events.syncModal(model, Modal.requestInvite);
                break;
            default:
                log.error("Unexpected interaction: " + inter);
                break;
            }
            break;
        case proxiedSites:
            if (handleModeSwitch(inter)) {
                break;
            }
            switch (inter) {
            case RESET:
                this.modelService.resetProxiedSites();
                this.internalState.setModalCompleted(Modal.proxiedSites);
                this.internalState.advanceModal(null);
                break;
            case CONTINUE:
                applyJson(json);
                this.internalState.setModalCompleted(Modal.proxiedSites);
                this.internalState.advanceModal(null);
                break;
            case LANTERNFRIENDS:
                log.debug("Processing lanternFriends from proxiedSites");
                Events.syncModal(model, Modal.lanternFriends);
                break;
            case SET:
                applyJson(json);
                break;
            case SETTINGS:
                log.debug("Processing settings from proxiedSites");
                Events.syncModal(model, Modal.settings);
                break;
            default:
                log.error("Did not handle interaction {}, for modal {} with " +
                    "params: {}", inter, modal, params);
                HttpUtils.sendClientError(resp, "unexpected interaction for proxied sites");
                break;
            }
            break;
        case requestInvite:
            log.error("Processing request invite");
            switch (inter) {
            case CANCEL:
                this.internalState.setModalCompleted(Modal.requestInvite);
                this.internalState.advanceModal(Modal.notInvited);
                break;
            case CONTINUE:
                applyJson(json);
                this.internalState.setModalCompleted(Modal.proxiedSites);
                //TODO: need to do something here
                this.internalState.advanceModal(null);
                break;
            default:
                log.error("Did not handle interaction {}, for modal {} with " +
                    "params: {}", inter, modal, params);
                HttpUtils.sendClientError(resp, "unexpected interaction for request invite");
                break;
            }
            break;
        case requestSent:
            log.debug("Process request sent");
            break;
        case settings:
            if (handleModeSwitch(inter)) {
                break;
            }
            switch (inter) {
            case GET:
                log.debug("Setting get mode");
                if (modelService.getMode() == Mode.give) {
                    //  need to do more setup to switch to get mode from give mode
                    model.setSetupComplete(false);
                    this.internalState.advanceModal(null);
                    Events.syncModal(model, Modal.proxiedSites);
                    Events.syncModel(this.model);
                }
                handleGiveGet(Mode.get);
                break;
            case GIVE:
                log.debug("Setting give mode");
                handleGiveGet(Mode.give);
                break;
            case CLOSE:
                log.debug("Processing settings close");
                Events.syncModal(model, Modal.none);
                break;
            case SET:
                log.debug("Processing set in setting...applying JSON\n{}", json);
                applyJson(json);
                break;
            case RESET:
                log.debug("Processing reset");
                Events.syncModal(model, Modal.confirmReset);
                break;
            case PROXIEDSITES:
                log.debug("Processing proxied sites in settings");
                Events.syncModal(model, Modal.proxiedSites);
                break;
            case LANTERNFRIENDS:
                log.debug("Processing friends in settings");
                Events.syncModal(model, Modal.lanternFriends);
                break;

            default:
                log.error("Did not handle interaction for modal {} with " +
                        "params: {}", modal, params);
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case settingsLoadFailure:
            log.error("Processing settings load failure...");
            break;
        case systemProxy:
            switch (inter) {
            case CONTINUE:
                log.debug("Processing continue in systemProxy", json);

                this.internalState.setModalCompleted(Modal.systemProxy);
                this.internalState.advanceModal(null);
                break;
            default:
                log.error("Did not handle interaction for modal {} with " +
                        "params: {}", modal, params);
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case updateAvailable:
            log.error("Did not handle interaction for modal {} with " +
                    "params: {}", modal, params);
            break;
        case authorizeLater:
            log.error("Did not handle interaction for modal {} with " +
                    "params: {}", modal, params);
            break;
        case confirmReset:
            log.debug("Handling confirm reset interaction");
            switch (inter) {
            case CANCEL:
                log.debug("Processing cancel");
                Events.syncModal(model, Modal.settings);
                break;
            case RESET:
                handleReset();
                Events.syncModel(this.model);
                break;
            default:
                log.error("Did not handle interaction for modal {} with " +
                        "params: {}", modal, params);
                HttpUtils.sendClientError(resp, "give or get required");
                break;
            }
            break;
        case contactDevs:
            if (handleModeSwitch(inter)) {
                break;
            }
            this.internalState.setModalCompleted(Modal.finished);
            this.internalState.advanceModal(null);
            Events.syncModel(this.model);
            break;
        case giveModeForbidden:
            log.error("Did not handle interaction for modal {} with " +
                    "params: {}", modal, params);
            break;
        default:
            log.error("No matching modal for {}", modal);
        }
        this.modelIo.write();
    }

    private void handleClose(String json) {
        if (StringUtils.isBlank(json)) {
            return;
        }
        final ObjectMapper om = new ObjectMapper();
        Map<String, Object> map;
        try {
            map = om.readValue(json, Map.class);
            final Integer notification = (Integer) map.get("notification");
            model.closeNotification(notification);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
        } catch (JsonParseException e) {
            e.printStackTrace();
        } catch (JsonMappingException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }

    }

    private void declineInvite(final String json) {
        final String email = JsonUtils.getValueFromJson("email", json);
        this.xmppHandler.unsubscribed(email);
    }

    private void acceptInvite(final String json) {
        final String email = JsonUtils.getValueFromJson("email", json);
        this.xmppHandler.subscribed(email);

        // We also automatically subscribe to them in turn so we know about
        // their presence.
        this.xmppHandler.subscribe(email);
    }

    private boolean handleModeSwitch(final Interaction inter) {
        switch (inter) {
        case SETTINGS:
            log.debug("Processing settings in none");
            Events.syncModal(model, Modal.settings);
            return true;
        case PROXIEDSITES:
            log.debug("Processing proxied sites in none");
            Events.syncModal(model, Modal.proxiedSites);
            return true;
        case LANTERNFRIENDS:
            log.debug("Processing friends in none");
            Events.syncModal(model, Modal.lanternFriends);
            return true;
        case ABOUT:
            log.debug("Processing about in none");
            Events.syncModal(model, Modal.about);
            return true;
        case CONTACT:
            log.debug("Processing contact in none");
            Events.syncModal(model, Modal.contactDevs);
            return true;
        default:
            return false;
        }
    }

    static class Invite {
        List<String> invite;

        public Invite() {}

        public List<String> getInvite() {
            return invite;
        }

        public void setInvite(List<String> invite) {
            this.invite = invite;
        }
    }
    private void invite(String json) {
        ObjectMapper om = new ObjectMapper();
        try {
            if (json.length() == 0) {
                return;//nobody to invite
            }
            ArrayList<String> invites = om.readValue(json, ArrayList.class);
            modelService.invite(invites);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private void handleSetModeWelcome(final Mode mode) {
        //this.model.getSettings().setMode(mode);
        this.modelService.setMode(mode);
        this.model.setModal(Modal.authorize);
        this.internalState.setModalCompleted(Modal.welcome);
        Events.eventBus().post(new SyncEvent(SyncPath.MODE, mode));
        Events.syncModal(model);
    }

    private void applyJson(final String json) {
        final JsonModelModifier mod = new JsonModelModifier(modelService);
        mod.applyJson(json);
    }

    private void handleGiveGet(final Mode mode) {
        Events.eventBus().post(new SyncEvent(SyncPath.MODE, mode));
        this.modelService.setMode(mode);
    }

    private void handleReset() {
        // This posts the reset event to any classes that need to take action,
        // avoiding coupling this class to those classes.
        Events.eventBus().post(new ResetEvent());
        if (LanternClientConstants.DEFAULT_MODEL_FILE.isFile()) {
            try {
                FileUtils.forceDelete(LanternClientConstants.DEFAULT_MODEL_FILE);
            } catch (final IOException e) {
                log.warn("Could not delete model file?");
            }
        }
        final Model base = new Model();
        model.setCache(base.isCache());
        model.setConnectivity(base.getConnectivity());
        model.setLaunchd(base.isLaunchd());
        model.setModal(base.getModal());
        model.setNinvites(base.getNinvites());
        model.setNodeId(base.getNodeId());
        model.setProfile(base.getProfile());
        model.setNproxiedSitesMax(base.getNproxiedSitesMax());
        model.setSettings(base.getSettings());
        model.setSetupComplete(base.isSetupComplete());
        model.setShowVis(base.isShowVis());
        modelIo.write();
    }

}
