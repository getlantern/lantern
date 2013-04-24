package org.lantern.http;

import java.io.File;
import java.io.IOException;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.HashSet;
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
import org.lantern.Censored;
import org.lantern.ConnectivityChangedEvent;
import org.lantern.JsonUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternFeedback;
import org.lantern.LanternUtils;
import org.lantern.XmppHandler;
import org.lantern.event.Events;
import org.lantern.event.InvitesChangedEvent;
import org.lantern.event.ResetEvent;
import org.lantern.state.Connectivity;
import org.lantern.state.InternalState;
import org.lantern.state.InviteQueue;
import org.lantern.state.JsonModelModifier;
import org.lantern.state.LocationChangedEvent;
import org.lantern.state.Modal;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelService;
import org.lantern.state.Notification.MessageType;
import org.lantern.state.Settings;
import org.lantern.state.SyncPath;
import org.lantern.util.Desktop;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
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
        DECLINE,
        UNEXPECTEDSTATERESET,
        UNEXPECTEDSTATEREFRESH,
        EXCEPTION
    }

    // modals the user can switch to from other modals
    private static final HashSet<Modal> switchModals = new HashSet<Modal>();
    static {
        switchModals.add(Modal.about);
        switchModals.add(Modal.contact);
        switchModals.add(Modal.settings);
        switchModals.add(Modal.proxiedSites);
        switchModals.add(Modal.lanternFriends);
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

    private final Censored censored;

    private final LanternFeedback lanternFeedback;

    private final InviteQueue inviteQueue;

    @Inject
    public InteractionServlet(final Model model,
        final ModelService modelService,
        final InternalState internalState,
        final ModelIo modelIo, final XmppHandler xmppHandler,
        final Censored censored, final LanternFeedback lanternFeedback,
        final InviteQueue inviteQueue) {
        this.model = model;
        this.modelService = modelService;
        this.internalState = internalState;
        this.modelIo = modelIo;
        this.xmppHandler = xmppHandler;
        this.censored = censored;
        this.lanternFeedback = lanternFeedback;
        this.inviteQueue = inviteQueue;
        Events.register(this);
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
        LanternUtils.addCSPHeader(resp);
        final String uri = req.getRequestURI();
        log.debug("Received URI: {}", uri);
        final String interactionStr = StringUtils.substringAfterLast(uri, "/");
        if (StringUtils.isBlank(interactionStr)) {
            log.debug("blank interaction");
            HttpUtils.sendClientError(resp, "blank interaction");
            return;
        }

        log.debug("Headers: "+HttpUtils.getRequestHeaders(req));

        if (!"XMLHttpRequest".equals(req.getHeader("X-Requested-With"))) {
            log.debug("invalid X-Requested-With");
            HttpUtils.sendClientError(resp, "invalid X-Requested-With");
            return;
        }

        if (!model.getXsrfToken().equals(req.getHeader("X-XSRF-TOKEN"))) {
            log.debug("X-XSRF-TOKEN wrong: got {} expected {}", req.getHeader("X-XSRF-TOKEN"), model.getXsrfToken());
            HttpUtils.sendClientError(resp, "invalid X-XSRF-TOKEN");
            return;
        }

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
            if (handleClose(json)) {
                return;
            }
        }

        final Modal modal = this.model.getModal();

        log.debug("processRequest: modal = {}, inter = {}, mode = {}", 
            modal, inter, this.model.getSettings().getMode());
        
        if (handleExceptionalInteractions(modal, inter, json)) {
            return; 
        }

        Modal switchTo = null;
        try {
            // XXX a map would make this more robust
            switchTo = Modal.valueOf(interactionStr);
        } catch (IllegalArgumentException e) { }
        if (switchTo != null && switchModals.contains(switchTo)) {
            if (!switchTo.equals(modal)) {
                if (!switchModals.contains(modal)) {
                    this.internalState.setLastModal(modal);
                }
                Events.syncModal(model, switchTo);
            }
            return;
        }

        switch (modal) {
        case welcome:
            this.model.getSettings().setMode(Mode.unknown);
            switch (inter) {
            case GET:
                log.debug("Setting get mode");
                handleSetModeWelcome(Mode.get);
                break;
            case GIVE:
                log.debug("Setting give mode");
                handleSetModeWelcome(Mode.give);
                break;
            }
            break;
        case authorize:
           log.debug("Processing authorize modal...");
            this.internalState.setModalCompleted(Modal.authorize);
            this.internalState.advanceModal(null);
            break;
        case finished:
            this.internalState.setCompletedTo(Modal.finished);
            switch (inter) {
            case CONTINUE:
                log.debug("Processing continue");
                model.setSetupComplete(true);
                Events.sync(SyncPath.SETUPCOMPLETE, true);
                this.model.setShowVis(true);
                Events.sync(SyncPath.SHOWVIS, true);
                this.internalState.setModalCompleted(Modal.finished);
                Events.syncModal(model, Modal.none);
                break;
            case SET:
                log.debug("Processing set in finished modal...applying JSON\n{}", 
                        json);
                applyJson(json);
                break;
            default:
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, 
                        "Interaction not handled for modal: "+modal+
                        " and interaction: "+inter);
                break;
            }
            break;
        case firstInviteReceived:
            log.error("Processing invite received...");
            break;
        case lanternFriends:
            this.internalState.setCompletedTo(Modal.lanternFriends);
            switch (inter) {
            case INVITE:
                invite(json);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
                break;
            case CONTINUE:
                /* fall-through */
            case CLOSE:
                log.debug("Processing continue/close for friends dialog");
                this.internalState.setModalCompleted(Modal.lanternFriends);
                this.internalState.advanceModal(null);
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
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, 
                    "Interaction not handled for modal: "+modal+
                    " and interaction: "+inter);
                break;
            }
            break;
        case none:
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
            this.internalState.setCompletedTo(Modal.proxiedSites);
            switch (inter) {
            case CONTINUE:
                this.internalState.setModalCompleted(Modal.proxiedSites);
                this.internalState.advanceModal(null);
                break;
            case LANTERNFRIENDS:
                log.debug("Processing lanternFriends from proxiedSites");
                Events.syncModal(model, Modal.lanternFriends);
                break;
            case SET:
                if (!model.getSettings().isSystemProxy()) {
                    String msg = "Because you are using manual proxy "
                            + "configuration, you may have to restart your "
                            + "browser for your updated proxied sites list "
                            + "to take effect.";
                    model.addNotification(msg, MessageType.info, 30);
                    Events.sync(SyncPath.NOTIFICATIONS,
                            model.getNotifications());
                }
                applyJson(json);
                break;
            case SETTINGS:
                log.debug("Processing settings from proxiedSites");
                Events.syncModal(model, Modal.settings);
                break;
            default:
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, "unexpected interaction for proxied sites");
                break;
            }
            break;
        case requestInvite:
            log.info("Processing request invite");
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
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, "unexpected interaction for request invite");
                break;
            }
            break;
        case requestSent:
            log.debug("Process request sent");
            break;
        case settings:
            switch (inter) {
            case GET:
                log.debug("Setting get mode");
                // Only deal with a mode change if the mode has changed!
                if (modelService.getMode() == Mode.give) {
                    // Break this out because it's set in the subsequent 
                    // setMode call
                    final boolean everGet = model.isEverGetMode();
                    this.modelService.setMode(Mode.get);
                    if (!everGet) {
                        // need to do more setup to switch to get mode from 
                        // give mode
                        model.setSetupComplete(false);
                        model.setModal(Modal.proxiedSites);
                        Events.syncModal(model, model.getModal());
                    } else {
                        // This primarily just triggers a setup complete event,
                        // which triggers connecting to proxies, setting up
                        // the local system proxy, etc.
                        model.setSetupComplete(true);
                    }
                }
                break;
            case GIVE:
                log.debug("Setting give mode");
                this.modelService.setMode(Mode.give);
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
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, 
                        "Interaction not handled for modal: "+modal+
                        " and interaction: "+inter);
                break;
            }
            break;
        case settingsLoadFailure:
            switch (inter) {
            case RETRY:
                modelIo.reload();
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
                Events.syncModal(model, model.getModal());
                break;
            case RESET:
                backupSettings();
                Events.syncModal(model, Modal.welcome);
                break;
            default:
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                break;
            }
            break;
        case systemProxy:
            this.internalState.setCompletedTo(Modal.systemProxy);
            switch (inter) {
            case CONTINUE:
                log.debug("Processing continue in systemProxy", json);
                applyJson(json);
                Events.sync(SyncPath.SYSTEMPROXY, model.getSettings().isSystemProxy());
                this.internalState.setModalCompleted(Modal.systemProxy);
                this.internalState.advanceModal(null);
                break;
            default:
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, "error setting system proxy pref");
                break;
            }
            break;
        case updateAvailable:

            switch (inter) {
            case CLOSE:
                this.internalState.setModalCompleted(Modal.updateAvailable);
                this.internalState.advanceModal(null);
                break;
            default:
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                break;
            }
            break;
        case authorizeLater:
            log.error("Did not handle interaction {} for modal {}", inter, modal);
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
                log.error("Did not handle interaction {} for modal {}", inter, modal);
                HttpUtils.sendClientError(resp, 
                        "Interaction not handled for modal: "+modal+
                        " and interaction: "+inter);
            }
            break;
        case about:
            switch (inter) {
            case CLOSE:
                Events.syncModal(model, this.internalState.getLastModal());
                break;
            default:
                HttpUtils.sendClientError(resp, "invalid interaction "+inter);
            }
            break;
        case contact:
            switch(inter) {
            case CONTINUE:
                String msg;
                MessageType messageType;
                try {
                    lanternFeedback.submit(json,
                        this.model.getProfile().getEmail());
                    msg = "Thank you for contacting Lantern.";
                    messageType = MessageType.info;
                } catch(Exception e) {
                    log.error("Error submitting contact form: {}", e);
                    msg = "Error sending message. Please check your "+
                        "connection and try again.";
                    messageType = MessageType.error;
                }
                model.addNotification(msg, messageType, 30);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            // fall through because this should be done in both cases:
            case CANCEL:
                Events.syncModal(model, this.internalState.getLastModal());
                break;
            default:
                HttpUtils.sendClientError(resp, "invalid interaction "+inter);

            }
            break;
        case giveModeForbidden:
            if (inter == Interaction.CONTINUE) {
                //  need to do more setup to switch to get mode from give mode
                model.setSetupComplete(false);
                this.internalState.advanceModal(null);
                Events.syncModal(model, Modal.proxiedSites);
                Events.sync(SyncPath.SETUPCOMPLETE, false);
            }
            break;
        default:
            log.error("No matching modal for {}", modal);
        }
        this.modelIo.write();
    }

    private void backupSettings() {
        try {
            File backup = new File(Desktop.getDesktopPath(), "lantern-model-backup");
            FileUtils.copyFile(LanternClientConstants.DEFAULT_MODEL_FILE, backup);
        } catch (final IOException e) {
            log.warn("Could not backup model file.");
        }
    }

    private boolean handleExceptionalInteractions(
            final Modal modal, final Interaction inter, final String json) {
        boolean handled = false;
        Map<String, Object> map;
        Boolean notify;
        switch(inter) {
            case EXCEPTION:
                handleException(json);
                handled = true;
                break;
            case UNEXPECTEDSTATERESET:
                log.debug("Handling unexpected state reset.");
                backupSettings();
                handleReset();
                Events.syncModel(this.model);
            // fall through because this should be done in both cases:
            case UNEXPECTEDSTATEREFRESH:
                try {
                    map = jsonToMap(json);
                } catch(Exception e) {
                    log.error("Bad json payload in inter '{}': {}", inter, json);
                    return true;
                }
                notify = (Boolean)map.get("notify");
                if(notify) {
                    try {
                        lanternFeedback.submit((String)map.get("report"),
                            this.model.getProfile().getEmail());
                    } catch(Exception e) {
                        log.error("Could not submit unexpected state report: {}\n {}",
                            e.getMessage(), (String)map.get("report"));
                    }
                }
                handled = true;
                break;
        }
        return handled;
    }

    private void handleException(final String json) {
        StringBuilder logMessage = new StringBuilder();
        Map<String, Object> map;
        try {
            map = jsonToMap(json);
        } catch(Exception e) {
            log.error("UI Exception (unable to parse json)");
            return;
        }
        for(Map.Entry<String, Object> entry : map.entrySet()) {
            logMessage.append(
                String.format("\t%s: %s\n", 
                    entry.getKey(), entry.getValue()
                )
            );
        }
        log.error("UI Exception:\n {}", logMessage.toString());
    }

    private Map<String, Object> jsonToMap(final String json) 
            throws JsonParseException, JsonMappingException, IOException {
        final ObjectMapper om = new ObjectMapper();
        Map<String, Object> map;
        map = om.readValue(json, Map.class);
        return map;
    }


    private boolean handleClose(String json) {
        if (StringUtils.isBlank(json)) {
            return false;
        }
        final ObjectMapper om = new ObjectMapper();
        Map<String, Object> map;
        try {
            map = om.readValue(json, Map.class);
            final String notification = (String) map.get("notification");
            model.closeNotification(Integer.parseInt(notification));
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            return true;
        } catch (JsonParseException e) {
            log.warn("Exception closing notifications {}", e);
        } catch (JsonMappingException e) {
            log.warn("Exception closing notifications {}", e);
        } catch (IOException e) {
            log.warn("Exception closing notifications {}", e);
        }
        return false;
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
            inviteQueue.invite(invites);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private void handleSetModeWelcome(final Mode mode) {
        this.model.setModal(Modal.authorize);
        this.internalState.setModalCompleted(Modal.welcome);
        this.modelService.setMode(mode);
        Events.syncModal(model);
    }

    private void applyJson(final String json) {
        final JsonModelModifier mod = new JsonModelModifier(modelService);
        mod.applyJson(json);
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
        model.setLaunchd(base.isLaunchd());
        model.setModal(base.getModal());
        model.setNinvites(base.getNinvites());
        model.setNodeId(base.getNodeId());
        model.setProfile(base.getProfile());
        model.setNproxiedSitesMax(base.getNproxiedSitesMax());
        //we need to keep clientID and clientSecret, because they are application-level settings
        String clientID = model.getSettings().getClientID();
        String clientSecret = model.getSettings().getClientSecret();
        model.setSettings(base.getSettings());
        model.getSettings().setClientID(clientID);
        model.getSettings().setClientSecret(clientSecret);
        model.setSetupComplete(base.isSetupComplete());
        model.setShowVis(base.isShowVis());
        model.clearNotifications();
        modelIo.write();
    }

    @Subscribe
    public void onLocationChanged(final LocationChangedEvent e) {
        Events.sync(SyncPath.LOCATION, e.getNewLocation());

        if (censored.isCountryCodeCensored(e.getNewCountry())) {
            if (!censored.isCountryCodeCensored(e.getOldCountry())) {
                //moving from uncensored to censored
                if (model.getSettings().getMode() == Mode.give) {
                    Events.syncModal(model, Modal.giveModeForbidden);
                }
            }
        }
    }

    @Subscribe
    public void onInvitesChanged(final InvitesChangedEvent e) {
        int newInvites = e.getNewInvites();
        if (e.getOldInvites() == 0) {
            String invitation = newInvites == 1 ? "invitation" : "invitations";
            String text = "You now have " + newInvites + " " + invitation;
            model.addNotification(text, MessageType.info);
        } else if (newInvites == 0 && e.getOldInvites() > 0) {
            model.addNotification("You have no more invitations. You will be notified when you receive more.", MessageType.important);
        }
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
    }

    @Subscribe
    public void onConnectivityChanged(final ConnectivityChangedEvent e) {
        boolean ipChanged = e.isIpChanged();
        Connectivity connectivity = model.getConnectivity();
        if (!e.isConnected()) {
            connectivity.setInternet(false);
            Events.sync(SyncPath.CONNECTIVITY_INTERNET, false);
            return;
        }
        if (ipChanged) {
            InetAddress ip = e.getNewIp();
            connectivity.setIp(ip.toString());
        }
        connectivity.setInternet(true);
        Events.sync(SyncPath.CONNECTIVITY, model.getConnectivity());

        Settings set = model.getSettings();

        if (set.getMode() == null || set.getMode() == Mode.unknown) {
            if (censored.isCensored()) {
                set.setMode(Mode.get);
            } else {
                set.setMode(Mode.give);
            }
        } else if (set.getMode() == Mode.give && censored.isCensored()) {
            // want to set the mode to get now so that we don't mistakenly
            // proxy any more than necessary
            set.setMode(Mode.get);
            log.info("Disconnected; setting giveModeForbidden");
            Events.syncModal(model, Modal.giveModeForbidden);
        }
    }
}
