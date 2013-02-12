package org.lantern.state;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.Map;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
            //final Object target = getTargetForPath(this.modelService, path);
            final String key = getMethodForPath(path);

            final Object val = map.get("value");
            setProperty(modelService, key, val, true);

            //setProperty(modelService, key, val, true);
        } catch (final JsonParseException e) {
            log.error("Problem handling JSON:"+json, e);
        } catch (final JsonMappingException e) {
            log.error("Problem handling JSON:"+json, e);
        } catch (final IOException e) {
            log.error("Problem handling JSON: "+json, e);
        }
    }

    private String getMethodForPath(final String path) {
        if (!path.contains("/")) {
            return path;
        }
        return StringUtils.substringAfter(path, "/");
    }

    private void setProperty(final Object bean,
        final String key, final Object obj, final boolean determineType) {
        log.info("Setting {} property on {} to "+obj, key, bean);
        try {
            PropertyUtils.setSimpleProperty(bean, key, obj);
        } catch (final IllegalAccessException e) {
            log.error("Could not set property '"+key+"' to '"+obj+"'", e);
        } catch (final InvocationTargetException e) {
            log.error("Could not set property '"+key+"' to '"+obj+"'", e);
        } catch (final NoSuchMethodException e) {
            log.error("Could not set property '"+key+"' to '"+obj+"'", e);
        }
    }
}
