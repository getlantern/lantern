package org.lantern.util;

import java.io.File;

import javax.swing.filechooser.FileSystemView;

import org.apache.commons.lang.SystemUtils;

public class Desktop {

    public static File getDesktopPath() {
        FileSystemView filesys = FileSystemView.getFileSystemView();

        File homeDirectory = filesys.getHomeDirectory();
        if (SystemUtils.IS_OS_WINDOWS) {
            //defaults to Desktop
            return homeDirectory;
        } else if (SystemUtils.IS_OS_LINUX) {
            return new File(homeDirectory, "Desktop");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            return new File(homeDirectory, "Desktop");
        } else {
            throw new RuntimeException("Unknown OS");
        }
    }
}
