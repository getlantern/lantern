package org.lantern;

import java.util.HashMap;
import java.util.Map;

/**
 * Class containing data about a new lantern version.
 */
public class UpdateData {

    private final String url;
    private final String version;

    public UpdateData() {
        this(new HashMap<String, String>());
    }
    
    public UpdateData(final Map<String, String> data) {
        this.version = data.get(LanternConstants.UPDATE_VERSION_KEY);
        this.url = data.get(LanternConstants.UPDATE_URL_KEY);
    }

    public String getUrl() {
        return url;
    }

    public String getVersion() {
        return version;
    }

}
