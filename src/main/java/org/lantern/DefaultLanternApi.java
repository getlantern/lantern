package org.lantern;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.lang.reflect.InvocationTargetException;
import java.security.GeneralSecurityException;
import java.util.Map;
import java.util.Map.Entry;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.httpclient.HttpStatus;
import org.apache.commons.lang.StringUtils;
import org.lantern.privacy.InvalidKeyException;
import org.lantern.privacy.LocalCipherProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Default implementation of the Lantern API.
 */
public class DefaultLanternApi implements LanternApi {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    /**
     * Enumeration of calls to the Lantern API.
     */
    private enum LanternApiCall {
        SIGNIN,
        SIGNOUT,
        APPLYAUTOPROXY,
        ADDTOWHITELIST,
        REMOVEFROMWHITELIST,
        ADDTRUSTEDPEER,
        REMOVETRUSTEDPEER,
        RESET,
        ROSTER,
        CONTACT,
        WHITELIST,
        SETLOCALPASSWORD,
        UNLOCK,
    }

    @Override
    public void processCall(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final String uri = req.getRequestURI();
        final String id = StringUtils.substringAfter(uri, "/api/");
        final LanternApiCall call = LanternApiCall.valueOf(id.toUpperCase());
        log.debug("Got API call {} for full URI: "+uri, call);
        switch (call) {
        case SIGNIN:
            handleSignin(req, resp);
            break;
        case SIGNOUT:
            handleSignout(resp);
            break;
        case APPLYAUTOPROXY:
            handleAutoproxy(resp);
            break;
        case RESET:
            handleReset(resp);
            break;
        case ADDTOWHITELIST:
            LanternHub.whitelist().addEntry(req.getParameter("site"));
            handleWhitelist(resp);
            LanternHub.settingsIo().write();
            break;
        case REMOVEFROMWHITELIST:
            LanternHub.whitelist().removeEntry(req.getParameter("site"));
            handleWhitelist(resp);
            LanternHub.settingsIo().write();
            break;
        case ADDTRUSTEDPEER:
            // TODO: Add data validation.
            LanternHub.getTrustedContactsManager().addTrustedContact(
                req.getParameter("email"));
            handleRoster(resp);
            break;
        case REMOVETRUSTEDPEER:
            // TODO: Add data validation.
            LanternHub.getTrustedContactsManager().removeTrustedContact(
                req.getParameter("email"));
            handleRoster(resp);
            break;
        case ROSTER:
            handleRoster(resp);
            break;
        case CONTACT:
            handleContactForm(req, resp);
            break;
        case WHITELIST:
            handleWhitelist(resp);
            break;
        case SETLOCALPASSWORD:
            handleSetLocalPassword(req, resp);
            break;
        case UNLOCK:
            handleUnlock(req, resp);
            break;            
        }
    }

    private void handleSignin(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final Settings set = LanternHub.settings();
        LanternHub.xmppHandler().disconnect();
        final Map<String, String> params = LanternUtils.toParamMap(req);

        final String rawEmail = params.remove("email");
        if (StringUtils.isBlank(rawEmail)) {
            sendError(resp, "No email address provided");
            return;
        }
        final String email;
        if (!rawEmail.contains("@")) {
            email = rawEmail + "@gmail.com";
        } else {
            email = rawEmail;
        }
        // important: keep in this order, changing email 
        // discards user settings associated with the old 
        // address (eg saved password if desired) -- 
        // the saved password is purposely not examined util
        // this setting has been changed (or not changed)
        changeSetting(resp, "email", email, false, false);
        
        String pass = params.remove("password");
        if (StringUtils.isBlank(pass) && set.isSavePassword()) {
            pass = set.getStoredPassword();
            if (StringUtils.isBlank(pass)) {
                sendError(resp, "No password given and no password stored");
                return;
            }
        }
        changeSetting(resp, "password", pass, false, false);
        log.info("Signing in with password: {}", pass);
        
        // We write to disk to make sure Lantern's considered configured for
        // the subsequent connect call.
        LanternHub.settingsIo().write();
        try {
            LanternHub.xmppHandler().connect();
            if (LanternUtils.shouldProxy() && LanternHub.settings().isInitialSetupComplete()) {
                // We automatically start proxying upon connect if the 
                // user's settings say they're in get mode and to use the 
                // system proxy.
                Proxifier.startProxying();
            }
        } catch (final IOException e) {
            sendError(resp, "Could not login: "+e.getMessage());
        } catch (final Proxifier.ProxyConfigurationError e) {
            log.error("Proxy configuration failed: {}", e);
        }
        returnSettings(resp);
    }


    private void handleSignout(final HttpServletResponse resp) {
        log.info("Signing out");
        _signout();
        returnSettings(resp);
    }

    private void handleAutoproxy(final HttpServletResponse resp) {
        try {
            if (LanternUtils.shouldProxy()) {
                Proxifier.startProxying();
            }
            else {
                Proxifier.stopProxying();
            }
        }
        catch (final Proxifier.ProxyConfigurationCancelled e) {
            sendServerError(resp, "Automatic proxy configuration cancelled.");
        }
        catch (final Proxifier.ProxyConfigurationError e) {
            sendServerError(resp, "Failed to configure system proxy.");
        }
    }

    private void handleReset(final HttpServletResponse resp) {
        try {
            _signout();
            
            LanternHub.destructiveFullReset();
            
            returnSettings(resp);
        } catch (final IOException e) {
            sendServerError(resp, "Error resetting settings: "+
               e.getMessage());
        }
    }
    
    private void _signout() {

        // We stop proxying outside of any user settings since if we're
        // not logged in there's no sense in proxying. Could theoretically
        // use cached proxies, but definitely no peer proxies would work.
        try {
            Proxifier.stopProxying();
        } catch (Proxifier.ProxyConfigurationError e) {
            log.error("failed to stop proxying: {}", e);
        }
        LanternHub.xmppHandler().disconnect();
        
        // clear user specific settings 
        // roster, trusted contacts, saved password
        
        
    }
    
    /** 
     * This set the *initial* local password for encrypting local 
     * settings in the case that the user specifies a password directly.
     * It fails if a password has already been set or the local cipher 
     * does not utilize a user supplied password.
     */
    private void handleSetLocalPassword(final HttpServletRequest req, 
                                        final HttpServletResponse resp) {
        final LocalCipherProvider lcp = LanternHub.localCipherProvider();
        if (lcp.isInitialized() == true) {
            sendError(resp, "Local password has already been set, must reset to change.");
            return;
        }
        if (!lcp.requiresAdditionalUserInput()) {
            sendError(resp, "Local cipher does not require password.");
            return;
        }
        final String password = req.getParameter("password");
        if (StringUtils.isBlank(password)) {
            sendError(resp, "Password cannot be blank");
            return;
        }
        try {
            lcp.feedUserInput(password.toCharArray(), true);
            // immediately "unlock" the settings
            LanternHub.resetSettings(true);
            SettingsState.State ss = LanternHub.settings().getSettings().getState();
            if (ss != SettingsState.State.SET) {
                sendServerError(resp, "Failed to intialize settings.");
                log.error("Settings did not unlock after initial set password, state is {}", ss);
                return;
            }
        } catch (final GeneralSecurityException e) {
            sendServerError(resp, "Error setting password.");
            log.error("Unexpected error setting initial password: {}", e);
        } catch (final IOException e) {
            sendServerError(resp, "Error setting password.");
            log.error("Unexpected error setting initial password: {}", e);
        }
    }
    
    /** 
     * unlock 
     */
    private void handleUnlock(final HttpServletRequest req, 
                              final HttpServletResponse resp) {
        final LocalCipherProvider lcp = LanternHub.localCipherProvider();
        if (lcp.isInitialized() == false) {
            sendError(resp, "Local password has not been set, must set first.");
            return;
        }
        if (!lcp.requiresAdditionalUserInput()) {
            sendError(resp, "Local cipher does not require password.");
            return;
        }
        final String password = req.getParameter("password");
        if (StringUtils.isBlank(password)) {
            sendError(resp, "Password cannot be blank");
            return;
        }
        try {
            // give it the password, *not intialization*
            lcp.feedUserInput(password.toCharArray(), false);
            // immediately "unlock" the settings
            LanternHub.resetSettings(true);
            SettingsState.State ss = LanternHub.settings().getSettings().getState();
            if (ss != SettingsState.State.SET) {
                log.error("Settings did not unlock, state is {}", ss);
                // still return the settings in this case so that the frontend
                // can deal with the state.
            }
            returnSettings(resp);

        } catch (final InvalidKeyException e) {
            /* bad password */
            sendError(resp, "Invalid password");
            return;
        } catch (final GeneralSecurityException e) {
            sendServerError(resp, "Error unlocking settings");
            log.error("Unexpected error unlocking settings: {}", e);
        } catch (final IOException e) {
            sendServerError(resp, "Error unlocking settings.");
            log.error("Unexpected error unlocking settings: {}", e);
        }
    }

    private void returnSettings(final HttpServletResponse resp) {
        final String json = LanternUtils.jsonify(LanternHub.settings(), Settings.UIStateSettings.class);
        returnJson(resp, json);
    }

    private void handleWhitelist(final HttpServletResponse resp) {
        final Whitelist wl = LanternHub.whitelist();
        returnJson(resp, wl);
    }


    private void handleRoster(final HttpServletResponse resp) {
        log.info("Processing roster call.");
        if (!LanternHub.xmppHandler().isLoggedIn()) {
            sendError(resp, "Not logged in!");
            return;
        }
        final Roster roster = LanternHub.roster();
        if (!roster.isEntriesSet()) {
            try {
                roster.populate();
            } catch (final IOException e) {
                sendError(resp, "Could not populate roster!");
                return;
            }
        }
        returnJson(resp, roster);
    }

    private void returnJson(final HttpServletResponse resp, final Object obj) {
        final String json = LanternUtils.jsonify(obj);
        returnJson(resp, json);
    }
    
    private void returnJson(final HttpServletResponse resp, final String json) {
        final byte[] body;
        try {
            body = json.getBytes("UTF-8");
        } catch (final UnsupportedEncodingException e) {
            log.error("We need UTF-8");
            return;
        }
        log.info("Returning json...");
        resp.setStatus(HttpStatus.SC_OK);
        resp.setContentLength(body.length);
        resp.setContentType("application/json; charset=UTF-8");
        resp.setHeader("Cache-Control", "no-cache,no-store,max-age=0");
        try {
            resp.getOutputStream().write(body);
            resp.getOutputStream().flush();
        } catch (final IOException e) {
            log.info("Could not write response", e);
        }
    }

    private void sendServerError(final HttpServletResponse resp, 
        final String msg) {
        try {
            resp.sendError(HttpStatus.SC_INTERNAL_SERVER_ERROR, msg);
        } catch (final IOException e) {
            log.info("Could not send error", e);
        }
    }
    
    private void sendError(final HttpServletResponse resp, final String msg) {
        try {
            resp.sendError(HttpStatus.SC_BAD_REQUEST, msg);
        } catch (final IOException e) {
            log.info("Could not send error", e);
        }
    }

    private void sendError(final Exception e, 
        final HttpServletResponse resp, final boolean sendErrors) {
        log.info("Caught exception", e);
        if (sendErrors) {
            try {
                resp.sendError(HttpStatus.SC_SERVICE_UNAVAILABLE, e.getMessage());
            } catch (final IOException ioe) {
                log.info("Could not send response", e);
            }
        }
    }

    @Override
    public void changeSetting(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final Map<String, String> params = LanternUtils.toParamMap(req);
        changeSetting(resp, params);

    }
    
    private void changeSetting(final HttpServletResponse resp,
        final Map<String, String> params) {
        if (params.isEmpty()) {
            sendError(resp, "You must set a setting");
            return;
        }
        final Entry<String, String> keyVal = params.entrySet().iterator().next();
        log.debug("Got keyval: {}", keyVal);
        final String key = keyVal.getKey();
        final String val = keyVal.getValue();
        changeSetting(resp, key, val);
    }
    
    private void changeSetting(final HttpServletResponse resp, final String key, 
        final String val) {
        changeSetting(resp, key, val, true);
    }
    
    private void changeSetting(final HttpServletResponse resp, final String key, 
            final String val, final boolean determineType) {
        changeSetting(resp, key, val, determineType, true);
    }

    private void changeSetting(final HttpServletResponse resp, final String key, 
        final String val, final boolean determineType, final boolean sync) {
        setProperty(LanternHub.settingsChangeImplementor(), key, val, false, 
            resp, determineType);
        setProperty(LanternHub.settings(), key, val, true, resp, determineType);
        resp.setStatus(HttpStatus.SC_OK);
        if (sync) {
            LanternHub.asyncEventBus().post(new SyncEvent());
            LanternHub.settingsIo().write();
        }
    }

    private void setProperty(final Object bean, 
        final String key, final String val, final boolean logErrors,
        final HttpServletResponse resp, final boolean determineType) {
        log.info("Setting property on {}", bean);
        final Object obj;
        if (determineType) {
            obj = LanternUtils.toTyped(val);
        } else {
            obj = val;
        }
        try {
            PropertyUtils.setSimpleProperty(bean, key, obj);
            //PropertyUtils.setProperty(bean, key, obj);
        } catch (final IllegalAccessException e) {
            sendError(e, resp, logErrors);
        } catch (final InvocationTargetException e) {
            sendError(e, resp, logErrors);
        } catch (final NoSuchMethodException e) {
            sendError(e, resp, logErrors);
        }
    }

    private void handleContactForm(HttpServletRequest req, HttpServletResponse resp) {
        final Map<String, String> params = LanternUtils.toParamMap(req);
        String message = params.get("message");
        String email = params.get("replyto");
        try {
            new LanternFeedback().submit(message, email);
        }
        catch (Exception e) {
            sendError(e, resp, true);
        }
    }

}
