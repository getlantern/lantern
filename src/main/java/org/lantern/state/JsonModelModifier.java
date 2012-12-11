package org.lantern.state;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.util.Map;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.LanternUtils;
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
            
            final String val = String.valueOf(map.get("value"));
            setProperty(modelService, key, val, true);
            
            //setProperty(modelService, key, val, true);
        } catch (final JsonParseException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (final JsonMappingException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (final IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }

    /**
     * Accesses the object to set a property on with a nested dot notation as
     * in object1.object2.
     * 
     * Public for testing. Note this is actually not use in favor of
     * ModelMutables that consolidates all accessible methods.
     */
    public Object getTargetForPath(final Object root, final String path) 
        throws IllegalAccessException, InvocationTargetException, NoSuchMethodException {
        if (!path.contains(".")) {
            return root;
        }
        final String curProp = StringUtils.substringBefore(path, ".");
        final Object propObject = PropertyUtils.getProperty(root, curProp);
        final String nextProp = StringUtils.substringAfter(path, ".");
        if (nextProp.contains(".")) {
            return getTargetForPath(propObject, nextProp);
        }
        return propObject;
    }
    

    private String getMethodForPath(final String path) {
        if (!path.contains(".")) {
            return path;
        }
        return StringUtils.substringAfter(path, ".");
    }

    private void setProperty(final Object bean, 
        final String key, final String val, final boolean determineType) {
        log.info("Setting {} property on {}", key, bean);
        final Object obj;
        if (determineType) {
            obj = LanternUtils.toTyped(val);
        } else {
            obj = val;
        }
        try {
            PropertyUtils.setSimpleProperty(bean, key, obj);
            //PropertyUtils.setProperty(bean, key, obj);
        } catch (final IllegalAccessException e) {
        } catch (final InvocationTargetException e) {
        } catch (final NoSuchMethodException e) {
        }
    }
}
