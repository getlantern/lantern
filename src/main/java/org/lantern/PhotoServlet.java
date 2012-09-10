package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collection;
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
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smackx.packet.VCard;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import eu.medsea.mimeutil.MimeType;
import eu.medsea.mimeutil.MimeUtil2;

/**
 * Servlet for sending photo data for a given user.
 */
public final class PhotoServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private XMPPConnection conn;
    
    private final int CACHE_DURATION_IN_SECOND = 60 * 60 * 24 * 4; 
    private final long CACHE_DURATION_IN_MS = CACHE_DURATION_IN_SECOND  * 1000;
    
    /**
     * Generated serial ID.
     */
    private static final long serialVersionUID = -8442913539662036158L;
    
    private final Map<String, VCard> cache = new HashMap<String, VCard>();
    
    private final byte[] noImage = loadNoImage();
    
    private final MimeUtil2 mimeUtil = new MimeUtil2();

    public PhotoServlet() {
        mimeUtil.registerMimeDetector(
            "eu.medsea.mimeutil.detector.MagicMimeMimeDetector");
        //Connection.DEBUG_ENABLED = true;
    }
    
    @Override
    protected void doGet(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException,
        IOException {
        log.debug("Got photo request: "+req.getRequestURI());
        final String email = req.getParameter("email");
        byte[] raw = null;
        if (StringUtils.isBlank(email)) {
            //sendError(resp, HttpStatus.SC_BAD_REQUEST, "email required");
            
        } else {
            if (cache.containsKey(email)) {
                raw = cache.get(email).getAvatar();
            } else {
                final VCard vcard;
                try {
                    vcard = XmppUtils.getVCard(establishConnection(), email);
                    raw = vcard.getAvatar();
                    cache.put(email, vcard);
                } catch (final XMPPException e) {
                    log.debug("Exception accessing vcard for "+email, e);
                } catch (final CredentialException e) {
                    sendError(resp, HttpStatus.SC_UNAUTHORIZED, 
                        "Could not authorize Google Talk connection");
                    return;
                }
            }
        }
        
        final byte[] imageData;
        if (raw == null) {
            imageData = noImage;
        } else {
            imageData = raw;
            final Collection<MimeType> types = mimeUtil.getMimeTypes(imageData);
            if (types != null && !types.isEmpty()) {
                final String ct = types.iterator().next().toString();
                resp.setContentType(ct);
                log.debug("Set content type to {}", ct);
            }
        }
        
        resp.addHeader(HttpHeaders.Names.CACHE_CONTROL, 
            "max-age=" + CACHE_DURATION_IN_SECOND);
        resp.setDateHeader(HttpHeaders.Names.EXPIRES, 
            System.currentTimeMillis() + CACHE_DURATION_IN_MS);
        
        resp.setContentLength(imageData.length);
        resp.getOutputStream().write(imageData);
        //resp.getOutputStream().close();
    }

    private byte[] loadNoImage() {
        final File none;
        final File installed = new File("default-profile-image.png");
        if (installed.isFile()) {
            none = installed;
        } else {
            none = new File("install/common/default-profile-image.png");
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
        if (conn != null && conn.isConnected()) {
            return conn;
        }
        final String user = LanternHub.xmppHandler().getLastUserName();
        final String pass = LanternHub.xmppHandler().getLastPass();
        if (StringUtils.isBlank(user)) {
            throw new IOException("No user name!!");
        }
        if (StringUtils.isBlank(user)) {
            throw new IOException("No password!!");
        }
        conn = XmppUtils.simpleGoogleTalkConnection(user, pass, "vcard-connection");
        return conn;
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
