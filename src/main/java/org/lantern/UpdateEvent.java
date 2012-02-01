package org.lantern;

import java.util.HashMap;
import java.util.Map;

/**
 * Class containing data about a new lantern version.
 */
public class UpdateEvent {

    private final Map<String, String> data;

    public UpdateEvent() {
        this(new HashMap<String, String>());
    }
    
    public UpdateEvent(final Map<String, String> data) {
        if (data == null) {
            this.data = new HashMap<String, String>();
        } else {
            this.data = data;
        }
    }

    public Map<String, String> getData() {
        return data;
    }

}
