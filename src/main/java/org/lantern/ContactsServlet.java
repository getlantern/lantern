package org.lantern;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ContactsServlet extends HttpServlet {

    private static final long serialVersionUID = -4663694729889856965L;
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    @Override
    protected void doGet(final HttpServletRequest request, 
        final HttpServletResponse response) throws ServletException, 
        IOException {
        log.info("Request URL: {}", request.getRequestURL());
        log.info("Handling request query: {}", request.getQueryString());
        
        final JSONObject json = new JSONObject();
        final JSONArray contacts = new JSONArray();
        final JSONObject test1 = new JSONObject();
        test1.put("name", "Adam Fisk");
        final JSONObject test2 = new JSONObject();
        test2.put("name", "Rachel Johnson");
        contacts.add(test1);
        contacts.add(test2);
        json.put("contacts", contacts);
        
        response.getWriter().write(json.toJSONString());
    }
}
