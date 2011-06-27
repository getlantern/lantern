package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import javax.servlet.ServletException;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Install1Servlet extends HttpServlet {

    private static final long serialVersionUID = -7539717861807079835L;
    private final Logger log = LoggerFactory.getLogger(getClass());

    @Override
    protected void doPost(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        log.info("Body: {}", request.getParameterMap());
        
        final String email = request.getParameter("email");
        final String pwd = request.getParameter("pwd");
        final Cookie[] cookies = request.getCookies();
        if (cookies.length < 1) {
            return;
        }
        String key = null;
        for (final Cookie cookie : cookies) {
            if (cookie.getName().equals("key")) {
                key = cookie.getValue();
                break;
            }
        }
        if (StringUtils.isBlank(key)) {
            return;
        }
        if (!key.equals(LanternUtils.keyString())) {
            return;
        }
        if (StringUtils.isNotBlank(email) && StringUtils.isNotBlank(pwd)) {
            response.addCookie(new Cookie("email", email));
            response.addCookie(new Cookie("pwd", pwd));
            response.sendRedirect(LanternConstants.BASE_URL + "/install2");
        }
    }
    
    @Override
    protected void doGet(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        log.info("Body: {}", request.getParameterMap());
        final String key = request.getParameter("key");
        if (!key.equals(LanternUtils.keyString())) {
            return;
        } else {
            response.addCookie(new Cookie("key", key));
        }
        final String errorText = request.getParameter("errorText");
        
        final File file = new File("srv/install1.html");
        final OutputStream os = response.getOutputStream();
        final InputStream is = new FileInputStream(file);
        final String str = IOUtils.toString(is, "UTF-8");
        final String errorDivContent;
        if (StringUtils.isBlank(errorText)) {
            errorDivContent = "";
        } else {
            errorDivContent = errorText;
        }
        
        final String page = str.replaceAll("error_div_content", errorDivContent);
        
        final byte[] bytes = page.getBytes("UTF-8");
        response.setContentLength(bytes.length);
        response.setContentType("text/html");
        os.write(bytes);
        
        IOUtils.closeQuietly(is);
    }
}
