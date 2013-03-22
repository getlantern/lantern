package org.lantern.state;

import java.io.IOException;

import org.codehaus.jackson.JsonNode;
import org.codehaus.jackson.JsonParser;
import org.codehaus.jackson.JsonProcessingException;
import org.codehaus.jackson.ObjectCodec;
import org.codehaus.jackson.map.DeserializationContext;
import org.codehaus.jackson.map.JsonDeserializer;

public class PeerCountDeserializer extends JsonDeserializer<PeerCount> {

    @Override
    public PeerCount deserialize(JsonParser jsonParser, DeserializationContext context)
            throws IOException, JsonProcessingException {
        ObjectCodec oc = jsonParser.getCodec();
        JsonNode node = oc.readTree(jsonParser);
        PeerCount count = new PeerCount();
        count.setGet(node.get("get").getLongValue());
        count.setGive(node.get("give").getLongValue());
        return count;

    }

}
