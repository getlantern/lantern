package org.lantern;

import java.io.IOException;

import org.codehaus.jackson.JsonGenerator;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.JsonSerializer;
import org.codehaus.jackson.map.SerializerProvider;

public class RosterSerializer extends JsonSerializer<Roster> {

    @Override
    public void serialize(Roster value, JsonGenerator jgen,
            SerializerProvider provider) throws IOException,
            JsonProcessingException {
        jgen.writeStartArray();
        for (LanternRosterEntry entry : value.getEntries()) {
            jgen.writeObject(entry);
        }
        jgen.writeEndArray();
    }


}
