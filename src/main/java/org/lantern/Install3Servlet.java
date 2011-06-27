package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Install3Servlet extends HttpServlet {
    
	private static final long serialVersionUID = 7329043730156806738L;
	private final Logger log = LoggerFactory.getLogger(getClass());

    @Override
    protected void doGet(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        
        final File file = new File("srv/install3.html");
        response.setContentLength((int) file.length());
        response.setContentType("text/html");
        final OutputStream os = response.getOutputStream();
        final InputStream is = new FileInputStream(file);
        IOUtils.copy(is, os);
        IOUtils.closeQuietly(is);
    }
}
