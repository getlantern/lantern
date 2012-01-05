package org.lantern;

import java.util.Map;

/**
 * Class for API calls to Lantern.
 */
public interface LanternApi {

    /**
     * Processes the specified API call data.
     * 
     * @param call The call data, including the id of the call and arguments.
     */
    void processCall(final Map<String, String> call);

    
}
