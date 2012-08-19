package org.lantern;

import java.io.IOException;

import javax.servlet.GenericServlet;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.UnavailableException;

import org.cometd.bayeux.server.BayeuxServer;
import org.cometd.java.annotation.ServerAnnotationProcessor;

public class BayeuxInitializer extends GenericServlet {
    
    private static final long serialVersionUID = -6884888598201660314L;

    @Override
    public void init() throws ServletException {
        super.init();
        final BayeuxServer bayeux = (BayeuxServer) getServletContext()
                .getAttribute(BayeuxServer.ATTRIBUTE);
        if (bayeux==null)
            throw new UnavailableException("No BayeuxServer!");

        // Create extensions
        //bayeux.addExtension(new TimesyncExtension());
        //bayeux.addExtension(new AcknowledgedMessagesExtension());
        final ServerAnnotationProcessor processor = 
            new ServerAnnotationProcessor(bayeux);
        processor.process(new SyncService(new CometDSyncStrategy()));
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
            throws ServletException, IOException {
        throw new ServletException();
    }
}
