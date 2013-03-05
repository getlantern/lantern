package org.lantern;

import java.io.IOException;

import org.codehaus.jackson.JsonParser;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.DeserializationContext;
import org.codehaus.jackson.map.JsonDeserializer;

public class RosterDeserializer extends JsonDeserializer<Roster> {

    @Override
    public Roster deserialize(JsonParser jp, DeserializationContext ctxt)
            throws IOException, JsonProcessingException {
        //we want to deserialize to null, because it
        //will get overwritten by the Roster created by
        //LanternModule
        jp.readValueAsTree();
        return null;
    }

}
