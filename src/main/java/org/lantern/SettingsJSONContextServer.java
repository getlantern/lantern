package org.lantern; 

import org.codehaus.jackson.map.ObjectMapper;
import org.cometd.server.JacksonJSONContextServer;

/** 
 * Customizes (de)serialization in cometd exchanges
 */
public class SettingsJSONContextServer extends JacksonJSONContextServer {
    
    public SettingsJSONContextServer() {
        final ObjectMapper mapper = getObjectMapper();
        mapper.setSerializationConfig(
            mapper.getSerializationConfig().withView(
                Settings.RuntimeSetting.class));
    }
}