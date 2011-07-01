package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URLEncoder;
import java.util.Collection;
import java.util.Map;
import java.util.Set;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.RosterEntry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Install2Servlet extends HttpServlet {

	private static final long serialVersionUID = -4883132226953321677L;
	private final Logger log = LoggerFactory.getLogger(getClass());

    @Override
    protected void doPost(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        
        if (!LanternUtils.isDebug()) {
            if (!LanternUtils.hasKeyCookie(request)) {
                return;
            }
        }
        
        final TrustedContactsManager tcm = 
            LanternHub.getTrustedContactsManager();
        final Map params = request.getParameterMap();
        final Set<String> keys = params.keySet();
        for (final String key : keys) {
            final String val = request.getParameter(key);
            if ("on".equalsIgnoreCase(val) || "true".equalsIgnoreCase(val)) {
                tcm.addTrustedContact(key);
            }
        }
        response.sendRedirect(LanternConstants.BASE_URL + "/install3");
    }
    
    @Override
    protected void doGet(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        
        if (!LanternUtils.isDebug()) {
            if (!LanternUtils.hasKeyCookie(request)) {
                return;
            }
        }
        
        final String contacts;
        try {
            contacts = contactsDiv(request, response);
        } catch (final IOException e) {
            LanternUtils.clear("google.user");
            LanternUtils.clear("google.pwd");
            return;
        }
        //log.info("Inserting contacts div: {}", contacts);
        final File file = new File("srv/install2.html");
        final OutputStream os = response.getOutputStream();
        final InputStream is = new FileInputStream(file);
        final String str = IOUtils.toString(is, "UTF-8");
        final String page = str.replaceAll("contacts_div", contacts);
        final byte[] raw = page.getBytes("UTF-8");
        response.setContentLength(raw.length);
        response.setContentType("text/html");
        os.write(raw);
        IOUtils.closeQuietly(is);
    }

    private String contactsDiv(final HttpServletRequest request, 
        final HttpServletResponse response) throws IOException {
        final String email = LanternUtils.getStringProperty("google.user");
        final String pwd = LanternUtils.getStringProperty("google.pwd");
        
        if (StringUtils.isBlank(email)) {
            sendError(response, "Please enter a valid e-mail address.");
        }
        if (StringUtils.isBlank(pwd)) {
            sendError(response, "Please enter a valid password.");
        }
        final Collection<RosterEntry> entries;
        try {
            entries = LanternUtils.getRosterEntries(email, pwd);
        } catch (final IOException e) {
            final String str = "Error logging in. Are you sure you " +
                "entered the correct user name and password?";
            sendError(response, str);
            return "";
        }
        
        final StringBuilder sb = new StringBuilder();
        sb.append("<div id='contacts'>\n");
        for (final RosterEntry entry : entries) {
            final String name = entry.getName();
            if (StringUtils.isBlank(name)) {
                continue;
            }
            final String user = entry.getUser();
            final String line = "<span class='contactName'>"+name+
                "</span><input type='checkbox' name='"+user+"' class='contactCheck'/>";
            sb.append("<div>");
            sb.append(line);
            sb.append("</div>\n");
            sb.append("<div style='clear: both'>");
            sb.append("</div>\n");
        }
        
        sb.append("</div>\n");
        return sb.toString();
    }

    private void sendError(final HttpServletResponse response, final String str) 
        throws IOException {
        final String msg = URLEncoder.encode(str, "UTF-8");
        response.sendRedirect(LanternConstants.BASE_URL + 
            "/install1?errorText="+msg);
        throw new IOException(str);
    }
}
