package org.lantern.state;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.Map;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.lantern.state.ModelService;

/**
 * Class that uses reflection to set properties on the state model.
 */
public class JsonModelModifier {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final ModelService modelService;

    public JsonModelModifier(final ModelService model) {
        this.modelService = model;
    }

    public void applyJson(final String json) {
        if (StringUtils.isBlank(json)) {
            log.debug("Ignoring empty json");
            return;
        }
        // The JSON object will only have two fields -- path and value, as in:
        // {"path":"settings.systemProxy","value":true}
        final ObjectMapper om = new ObjectMapper();
        try {
            final Map<String, Object> map = om.readValue(json, Map.class);
            final String path = (String) map.get("path");

            final Object val = map.get("value");
            LanternUtils.setFromPath(modelService, path, val);

            //setProperty(modelService, key, val, true);
        } catch (final JsonParseException e) {
            log.error("Problem handling JSON:"+json, e);
        } catch (final JsonMappingException e) {
            log.error("Problem handling JSON:"+json, e);
        } catch (final IOException e) {
            log.error("Problem handling JSON: "+json, e);
        } catch (IllegalAccessException e) {
            log.error("Problem handling JSON: "+json, e);
        } catch (InvocationTargetException e) {
            log.error("Problem handling JSON: "+json, e);
        } catch (NoSuchMethodException e) {
            log.error("Problem handling JSON: "+json, e);
        }
    }

}
