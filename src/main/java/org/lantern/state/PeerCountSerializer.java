package org.lantern.state;

import java.io.IOException;

import org.codehaus.jackson.JsonGenerator;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.map.JsonSerializer;
import org.codehaus.jackson.map.SerializerProvider;

public class PeerCountSerializer extends JsonSerializer<PeerCount> {

    @Override
    public void serialize(PeerCount obj, JsonGenerator jgen,
            SerializerProvider provider) throws IOException,
            JsonProcessingException {
        jgen.writeStartObject();
        jgen.writeObjectField("get", obj.get);
        jgen.writeObjectField("give", obj.give);
        jgen.writeObjectField("giveGet", obj.give + obj.get);
        jgen.writeEndObject();
    }

}
