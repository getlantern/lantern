package org.lantern;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.Map;
import java.util.Map.Entry;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.httpclient.HttpStatus;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Default implementation of the Lantern API.
 */
public class DefaultLanternApi implements LanternApi {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final SettingsChangeImplementor implementor =
        new SettingsChangeImplementor();
    
    /**
     * Enumeration of calls to the Lantern API.
     */
    private enum LanternApiCall {
        INIT, // call dashboard makes on connect to get pushed initial state
              // XXX can we use some cometd onConnect hook for this instead?
        SIGNIN,
        SIGNOUT,
        ADDTOWHITELIST,
        REMOVEFROMWHITELIST,
        ADDTRUSTEDPEER,
        REMOVETRUSTEDPEER,
    }

    @Override
    public void processCall(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final String uri = req.getRequestURI();
        final String id = StringUtils.substringAfter(uri, "/api/");
        final LanternApiCall call = LanternApiCall.valueOf(id.toUpperCase());
        log.debug("Got API call {}", call);
        switch (call) {
        case SIGNIN:
            LanternHub.xmppHandler().disconnect();
            final String email = req.getParameter("email");
            final String pass = req.getParameter("password");
            LanternHub.userInfo().setEmail(email);
            LanternHub.userInfo().setPassword(pass);
            LanternHub.xmppHandler().connect();
            break;
        case SIGNOUT:
            LanternHub.xmppHandler().disconnect();
            break;
        case ADDTOWHITELIST:
            LanternHub.whitelist().addEntry(req.getParameter("site"));
            break;
        case REMOVEFROMWHITELIST:
            LanternHub.whitelist().removeEntry(req.getParameter("site"));
            break;
        case ADDTRUSTEDPEER:
            // TODO: Add data validation.
            LanternHub.getTrustedContactsManager().addTrustedContact(
                req.getParameter("email"));
            break;
        case REMOVETRUSTEDPEER:
            // TODO: Add data validation.
            LanternHub.getTrustedContactsManager().removeTrustedContact(
                req.getParameter("email"));
            break;
        }
        LanternHub.eventBus().post(new SyncEvent());
    }
    
    private enum Category {
        SYSTEM,
        USER,
        WHITELIST,
        ROSTER,
    }

    @Override
    public void changeSetting(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final String uri = req.getRequestURI();
        final String path = StringUtils.substringAfter(uri, "/settings/");
        log.info("Got path: {}", path);
        final String category = StringUtils.substringBefore(path, "/");
        log.info("Got category: {}", category);
        
        //final String query = req.getQueryString();
        final Map<String, String> params = LanternUtils.toParamMap(req);
        final Entry<String, String> keyVal = params.entrySet().iterator().next();
        log.info("Got keyval: {}", keyVal);
        final String key = keyVal.getKey();
        final String val = keyVal.getValue();
        final Category cat = Category.valueOf(category.toUpperCase());
        switch (cat) {
        case SYSTEM:
            setProperty(LanternHub.systemInfo(), key, val, true, resp);
            break;
        case USER:
            setProperty(LanternHub.userInfo(), key, val, true, resp);
            break;
        case WHITELIST:
            setProperty(LanternHub.whitelist(), key, val, true, resp);
            break;
        case ROSTER:
            setProperty(LanternHub.roster(), key, val, true, resp);
            break;
        }
        setProperty(implementor, key, val, false, resp);
        resp.setStatus(HttpStatus.SC_OK);
    }
    
    private void setProperty(final Object bean, 
        final String key, final String val, final boolean logErrors,
        final HttpServletResponse resp) {
        log.info("Setting property on {}", bean);
        final Object obj;
        if (LanternUtils.isTrue(val)) {
            obj = true;
        } else if (LanternUtils.isFalse(val)) {
            obj = false;
        } else if (NumberUtils.isNumber(val)) {
            obj = Integer.parseInt(val);
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

    private void sendError(final Exception e, 
        final HttpServletResponse resp, final boolean logErrors) {
        if (logErrors) {
            try {
                resp.sendError(HttpStatus.SC_SERVICE_UNAVAILABLE, e.getMessage());
            } catch (final IOException ioe) {
                log.info("Could not send response", e);
            }
        }
    }

}
