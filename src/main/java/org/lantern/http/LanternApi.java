package org.lantern.http;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 * Class for API calls to Lantern.
 */
public interface LanternApi {

    /**
     * Processes the specified API call data.
     * 
     * @param req The request
     * @param resp The response.
     */
    void processCall(HttpServletRequest req, HttpServletResponse resp);

    
    void changeSetting(HttpServletRequest req, HttpServletResponse resp);

    
}
