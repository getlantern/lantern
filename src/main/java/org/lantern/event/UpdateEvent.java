package org.lantern.event;

import java.util.HashMap;
import java.util.Map;

/**
 * Class containing data about a new lantern version.
 */
public class UpdateEvent {

    private final Map<String, Object> data;

    public UpdateEvent() {
        this(new HashMap<String, Object>());
    }
    
    public UpdateEvent(final Map<String, Object> data) {
        if (data == null) {
            this.data = new HashMap<String, Object>();
        } else {
            this.data = data;
        }
    }

    public Map<String, Object> getData() {
        return data;
    }

}
