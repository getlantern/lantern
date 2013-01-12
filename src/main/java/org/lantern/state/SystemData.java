package org.lantern.state;

import java.awt.Dimension;
import java.awt.Toolkit;
import java.io.IOException;
import java.lang.management.ManagementFactory;

import org.apache.commons.io.FileSystemUtils;
import org.apache.commons.lang3.SystemUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.state.Model.Run;

import com.sun.management.OperatingSystemMXBean;

/**
 * Class containing data about the users system.
 */
public class SystemData {

    private final String os;
    private long bytesFree;
    private final long memory;
    
    public SystemData() {
        
        if (SystemUtils.IS_OS_MAC_OSX) {
            os = "osx";
        } else if (SystemUtils.IS_OS_WINDOWS) {
            os = "windows";
        } else {
            os = "ubuntu";
        }
        try {
            bytesFree = FileSystemUtils.freeSpaceKb() * 1024;
        } catch (final IOException e) {
            bytesFree = 1000000000L;
        }
        final OperatingSystemMXBean operatingSystemMXBean = 
            (OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
        memory = operatingSystemMXBean.getTotalPhysicalMemorySize();
    }
    
    @JsonView({Run.class})
    public String getLang() {
        return SystemUtils.USER_LANGUAGE;
    }
    
    @JsonView({Run.class})
    public String getOs() {
        return os;
    }

    @JsonView({Run.class})
    public String getVersion() {
        return SystemUtils.OS_VERSION;
    }

    @JsonView({Run.class})
    public String getArch() {
        return SystemUtils.OS_ARCH;
    }

    public long getBytesFree() {
        return bytesFree;
    }

    public long getMemory() {
        return memory;
    }

    public String getJava() {
        return SystemUtils.JAVA_VERSION;
    }

    public double[] getScreenSize() {
        final double[] screenSize = new double[2];
        final Toolkit toolkit =  Toolkit.getDefaultToolkit ();
        final Dimension screen  = toolkit.getScreenSize();
        screenSize[0] = screen.getWidth();
        screenSize[1] = screen.getHeight();
        return screenSize;
    }
    
}
