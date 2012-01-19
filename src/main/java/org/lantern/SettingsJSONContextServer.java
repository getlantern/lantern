package org.lantern; 

import org.cometd.server.JacksonJSONContextServer;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.map.SerializationConfig; 

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