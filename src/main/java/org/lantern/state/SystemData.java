package org.lantern.state;

import org.apache.commons.lang.SystemUtils;

/**
 * Class containing data about the users system.
 */
public class SystemData {

    public String getLang() {
        return SystemUtils.USER_LANGUAGE;
    }
    
    public String getOs() {
        return SystemUtils.OS_NAME;
    }
}
