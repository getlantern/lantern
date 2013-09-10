package org.lantern.http;

import io.netty.handler.codec.http.HttpHeaders;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

import javax.security.auth.login.CredentialException;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.httpclient.HttpStatus;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smackx.packet.VCard;
import org.lantern.LanternUtils;
import org.lantern.oauth.LanternGoogleOAuth2Credentials;
import org.lantern.state.ModelUtils;
import org.lantern.state.StaticSettings;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

//import eu.medsea.mimeutil.MimeType;
//import eu.medsea.mimeutil.MimeUtil2;

/**
 * Servlet for sending photo data for a given user.
 */
@Singleton
public final class PhotoServlet extends HttpServlet {

    private static final Logger log = LoggerFactory.getLogger(PhotoServlet.class);
    
    private static XMPPConnection conn;
    
    private static final int CACHE_DURATION_IN_S = 60 * 60 * 24; // 1 day
    private static final long CACHE_DURATION_IN_MS = CACHE_DURATION_IN_S * 1000;
    
    /**
     * Generated serial ID.
     */
    private static final long serialVersionUID = -8442913539662036158L;
    
    private static final Map<String, VCard> cache = new HashMap<String, VCard>();
    
    private final byte[] noImage = loadNoImage();
    
    //private static final MimeUtil2 mimeUtil = new MimeUtil2();
    
    private static final Object CONNECTION_LOCK = new Object();

    private final ModelUtils modelUtils;

    @Inject
    public PhotoServlet(final ModelUtils modelUtils) {
        this.modelUtils = modelUtils;
        /*
        mimeUtil.registerMimeDetector(
            "eu.medsea.mimeutil.detector.MagicMimeMimeDetector");
            */
        //Connection.DEBUG_ENABLED = true;
    }
    
    @Override
    protected void doGet(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException,
        IOException {
        LanternUtils.addCSPHeader(resp);
        final String referer = req.getHeader(HttpHeaders.Names.REFERER);
        log.debug("Referer is: {}", referer);
        final String localEndpoint = StaticSettings.getLocalEndpoint();
        if (!referer.startsWith(localEndpoint)) {
            sendError(resp, HttpStatus.SC_BAD_REQUEST, 
                "referer must be localhost");
            return;
        }

        log.debug("Got photo request: {}", req.getRequestURI());
        final String email = req.getParameter("email");
        final byte[] imageData;
        if (StringUtils.isBlank(email)) {
            sendError(resp, HttpStatus.SC_BAD_REQUEST, "email required");
            return;
        } 
        
        if (email.equals("default")) {
            log.debug("Serving default photo!!");
            imageData = noImage;
        } else {
        
            // In theory here we could hit another Google API to avoid
            // shoving all this data through XMPP, although it probably doesn't
            // matter much -- a TCP pipe is a TCP pipe after all.
            byte[] raw = null;
            try {
                raw = getVCard(email).getAvatar();
            } catch (final CredentialException e) {
                sendError(resp, HttpStatus.SC_UNAUTHORIZED, 
                    "Could not authorize Google Talk connection");
                return;
            } catch (final XMPPException e) {
                log.debug("Exception accessing vcard for "+email);
            }
            if (raw == null) {
                imageData = noImage;
            } else {
                imageData = raw;
                /*
                final Collection<MimeType> types = mimeUtil.getMimeTypes(imageData);
                if (types != null && !types.isEmpty()) {
                    final String ct = types.iterator().next().toString();
                    resp.setContentType(ct);
                    log.debug("Set content type to {}", ct);
                }
                */
            }
        }
        
        
        resp.addHeader(HttpHeaders.Names.CACHE_CONTROL, 
            "max-age=" + CACHE_DURATION_IN_S);
        resp.setDateHeader(HttpHeaders.Names.EXPIRES, 
            System.currentTimeMillis() + CACHE_DURATION_IN_MS);
        
        resp.setContentLength(imageData.length);
        resp.getOutputStream().write(imageData);
        //resp.getOutputStream().close();
    }
    
    public VCard getVCard(final String email) 
        throws CredentialException, XMPPException, IOException {
        
        if (StringUtils.isBlank(email)) {
            //sendError(resp, HttpStatus.SC_BAD_REQUEST, "email required");
            throw new NullPointerException("No email!");
        } else {
            if (cache.containsKey(email)) {
                return cache.get(email);
            } else {
                final VCard vcard = XmppUtils.getVCard(establishConnection(), email);
                cache.put(email, vcard);
                return vcard;
            }
        }
    }

    private byte[] loadNoImage() {
        final File none;
        final File installed = new File("lantern-ui/img/default-avatar.png");//default-profile-image.png");
        if (installed.isFile()) {
            none = installed;
        } else {
            none = new File("lantern-ui/app/img/default-avatar.png");
        }
        
        InputStream is = null;
        try {
            is = new FileInputStream(none);
            return IOUtils.toByteArray(is);
        } catch (final IOException e) {
            log.error("No default profile image?", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        return new byte[0];
    }

    private XMPPConnection establishConnection() throws CredentialException, 
        XMPPException, IOException {
        // The browser will send a bunch of requests for photos, and we don't
        // want to hammer the Google Talk servers, so we synchronize to 
        // create a single connection.
        synchronized (CONNECTION_LOCK) {
            if (conn != null && conn.isConnected()) {
                return conn;
            }
            
            final LanternGoogleOAuth2Credentials  cred = 
                this.modelUtils.newGoogleOauthCreds("vcard-connection");

            conn = XmppUtils.simpleGoogleTalkConnection(cred);
            return conn;
        }
    }

    private void sendError(final HttpServletResponse resp, final int errorCode, 
        final String msg) {
        try {
            resp.sendError(errorCode, msg);
        } catch (final IOException e) {
            log.debug("Could not send response", e);
        }
    }
    
    @Override
    protected void doPost(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException, 
        IOException {
    }
}
