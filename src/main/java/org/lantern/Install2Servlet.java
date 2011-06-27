package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Collection;

import javax.servlet.ServletException;
import javax.servlet.http.Cookie;
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
    protected void doGet(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        
        final String contacts = contactsDiv(request);
        log.info("Inserting contacts div: {}", contacts);
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

    private String contactsDiv(final HttpServletRequest request) 
        throws IOException {
        final Cookie[] cookies = request.getCookies();
        String email = null;
        String pwd = null;
        for (final Cookie cook : cookies) {
            final String name = cook.getName();
            if (name.equals("email")) {
                email = cook.getValue();
            } else if (name.equals("pwd")) {
                pwd = cook.getValue();
            }
        }
        if (StringUtils.isBlank(email) || StringUtils.isBlank(pwd)) {
            return "";
        }
        final Collection<RosterEntry> entries = 
            LanternUtils.getRosterEntries(email, pwd);
        
        final StringBuilder sb = new StringBuilder();
        sb.append("<div id='contacts'>\n");
        for (final RosterEntry entry : entries) {
            final String name = entry.getName();
            final String line = "<span style='float:left'>"+name+
                "</span><input id='"+name+"' type='checkbox' name='"+name+"' style='float:right'/>";
            sb.append("<div>");
            sb.append(line);
            sb.append("</div>\n");
            sb.append("<div style='clear: both'>");
            sb.append("</div>\n");
        }
        
        sb.append("</div>\n");
        return sb.toString();
    }
}
