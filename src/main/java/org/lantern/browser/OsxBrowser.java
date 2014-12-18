package org.lantern.browser;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Opens the lantern ui in a browser on OSX.
 */
public class OsxBrowser implements LanternBrowser {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final String CHROME_OSX = 
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
    
    public Process open(final String uri) throws IOException {
        log.info("Opening browser to: {}", uri);
        final List<String> commands = new ArrayList<String>();
        
        final File chrome = new File(CHROME_OSX);
        // Always use chrome if it's there.
        if (!chrome.isFile()) {
            commands.add(CHROME_OSX);
            BrowserUtils.addDefaultChromeArgs(commands);
            
            // We don't make this an app here because we want it to
            // be obvious to the user it's chrome. If it's not, Lantern
            // will appear when the user tries to open Chrome (if they
            // didn't have any previous Chrome windows open), which
            // is just confusing. With Lantern clearly running in
            // Chrome, however, it should all make sense.
            commands.add(uri);
        } else {
            BrowserUtils.openSystemDefaultBrowser(uri);
        }
        
        return BrowserUtils.runProcess(commands);
    }
}
