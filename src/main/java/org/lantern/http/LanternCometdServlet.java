package org.lantern.http;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.cometd.server.CometdServlet;
import org.lantern.LanternUtils;

public class LanternCometdServlet extends CometdServlet {
    private static final long serialVersionUID = -8425331352519040246L;

    @Override
    public void service(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        LanternUtils.addCSPHeader(resp);
        super.service(req, resp);
    }
}
