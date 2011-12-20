package org.lantern;

import org.apache.commons.lang.SystemUtils;

/**
 * Platform data.
 */
public class Platform {

    public String getOsName() {
        return SystemUtils.OS_NAME;
    }
    public String getOsversion() {
        return SystemUtils.OS_VERSION;
    }
    public String getOsArch() {
        return SystemUtils.OS_ARCH;
    }
    
}
