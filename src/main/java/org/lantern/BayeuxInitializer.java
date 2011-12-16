package org.lantern;

import java.io.IOException;

import javax.servlet.GenericServlet;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

import org.cometd.bayeux.server.BayeuxServer;

public class BayeuxInitializer extends GenericServlet {
    
    private static final long serialVersionUID = -6884888598201660314L;

    @Override
    public void init() throws ServletException {
        final BayeuxServer bayeux = (BayeuxServer) getServletContext()
                .getAttribute(BayeuxServer.ATTRIBUTE);
        new SyncService(bayeux);
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
            throws ServletException, IOException {
        throw new ServletException();
    }
}
