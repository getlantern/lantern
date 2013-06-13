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
    private double[] screenSize;
    
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

    @JsonView({Run.class})
    public long getBytesFree() {
        return bytesFree;
    }

    @JsonView({Run.class})
    public long getMemory() {
        return memory;
    }

    @JsonView({Run.class})
    public String getJava() {
        return SystemUtils.JAVA_VERSION;
    }

    @JsonView({Run.class})
    public double[] getScreenSize() {
        if (this.screenSize != null) {
            return this.screenSize;
        }
        final double[] ss = new double[2];
        try {
            final Toolkit toolkit =  Toolkit.getDefaultToolkit ();
            final Dimension screen  = toolkit.getScreenSize();
            ss[0] = screen.getWidth();
            ss[1] = screen.getHeight();
            this.screenSize = ss;
        } catch (final Exception e) {
            // We might not be able to get the screen size if we're running
            // in headless mode, for example.
            this.screenSize = new double[2];
        }
        return this.screenSize;
    }
}
