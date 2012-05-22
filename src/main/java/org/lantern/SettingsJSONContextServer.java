package org.lantern; 

import org.codehaus.jackson.map.ObjectMapper;
import org.cometd.server.JacksonJSONContextServer;

/** 
 * customizes (de)serialization in cometd exchanges
 */
public class SettingsJSONContextServer extends JacksonJSONContextServer {
    
    public SettingsJSONContextServer() {
        ObjectMapper mapper = getObjectMapper();
        mapper.setSerializationConfig(
            mapper.getSerializationConfig().withView(
                Settings.UIStateSettings.class));
    }
}