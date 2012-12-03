package org.lantern.state;

import org.apache.commons.lang.SystemUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.state.Model.Run;

/**
 * Class containing data about the users system.
 */
public class SystemData {

    @JsonView({Run.class})
    public String getLang() {
        return SystemUtils.USER_LANGUAGE;
    }
    
    @JsonView({Run.class})
    public String getOs() {
        return SystemUtils.OS_NAME;
    }
}
