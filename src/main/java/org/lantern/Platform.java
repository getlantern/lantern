package org.lantern;

import org.apache.commons.lang.SystemUtils;

/**
 * Platform data.
 */
public class Platform {

    private String osName = SystemUtils.OS_NAME;
    private String osArch = SystemUtils.OS_ARCH;
    private String osVersion = SystemUtils.OS_VERSION;
    
    public String getOsName() {
        return osName;
    }
    public void setOsName(String osName) {
        this.osName = osName;
    }
    public String getOsArch() {
        return osArch;
    }
    public void setOsArch(String osArch) {
        this.osArch = osArch;
    }
    public String getOsVersion() {
        return osVersion;
    }
    public void setOsVersion(String osVersion) {
        this.osVersion = osVersion;
    }
}
