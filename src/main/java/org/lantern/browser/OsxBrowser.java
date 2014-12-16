package org.lantern.browser;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternClientConstants;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Opens the lantern ui in a browser on OSX.
 */
public class OsxBrowser implements LanternBrowser {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final int windowWidth;
    private final int windowHeight;
    
    private static final String CHROME_OSX = 
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
    private static final String FIREFOX_OSX = 
            "/Applications/Firefox.app/Contents/MacOS/firefox";
    
    public OsxBrowser(final int windowWidth, final int windowHeight) {
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
    }
    
    public Process open(final String uri) throws IOException {
        log.info("Opening browser to: {}", uri);
        final List<String> commands = new ArrayList<String>();
        
        final File chrome = new File(CHROME_OSX);
        final File firefox = new File(FIREFOX_OSX);
        // Always use chrome if it's there.
        if (chrome.isFile()) {
            commands.add(CHROME_OSX);
            
            // We need to use a custom data directory because if we
            // don't the process ID we get back will correspond with
            // something other than the process we need to kill, causing
            // the window not to close. Not sure why, but that's what
            // happens.
            commands.add("--user-data-dir="
                    + LanternClientConstants.CONFIG_DIR.getAbsolutePath());
            //commands.add("--window-size=" + windowWidth + "," + windowHeight);
            //commands.add("--window-position=" + location.x + "," + location.y);
            BrowserUtils.addDefaultChromeArgs(commands, windowWidth, windowHeight);
            
            // We don't make this an app here because we want it to
            // be obvious to the user it's chrome. If it's not, Lantern
            // will appear when the user tries to open Chrome (if they
            // didn't have any previous Chrome windows open), which
            // is just confusing. With Lantern clearly running in
            // Chrome, however, it should all make sense.
            commands.add(uri);
        } else if (firefox.isFile()) {
            commands.add(FIREFOX_OSX);
            commands.add("-width " + windowWidth);
            commands.add("-height " + windowHeight);
            commands.add(uri);
        } else {
            final String webview = webViewPath();
            if (StringUtils.isNotBlank(webview)) {
                commands.add(webview);
                commands.add(uri);
            }
        }
        
        return BrowserUtils.runProcess(commands);
    }
    
    private String webViewPath() {
        final File path1 = new File("install/osx/Lantern.app/Contents/MacOS/Lantern");
        if (path1.isFile() && path1.canExecute()) return path1.getAbsolutePath();
        final File path2 = new File("Lantern.app/Contents/MacOS/Lantern");
        if (path2.isFile() && path2.canExecute()) return path2.getAbsolutePath();
        log.warn("Could not find LanternBrowser");
        return null;
    }
}
