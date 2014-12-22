package org.lantern.browser;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Opens the Lantern UI in a browser on Ubuntu.
 */
public class UbuntuBrowser implements LanternBrowser {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final int windowWidth;
    private final int windowHeight;
    
    /**
     * Creates a new Ubuntu browser.
     * 
     * @param windowWidth The desired width of the window.
     * @param windowHeight The desired height of the window.
     */
    public UbuntuBrowser(final int windowWidth, final int windowHeight) {
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
    }
    
    @Override
    public Process open(final String uri) throws IOException {
        log.info("Opening browser to: {}", uri);
        final Collection<String> pathCandidates = new ArrayList<String>();
        pathCandidates.add("/usr/bin/google-chrome");
        pathCandidates.add("/usr/bin/google-chrome-stable");
        pathCandidates.add("/usr/bin/google-chrome-unstable");
        pathCandidates.add("/usr/bin/chromium");
        pathCandidates.add("/usr/bin/chromium-browser");
        pathCandidates.add("/usr/bin/google-chrome-beta");
        for (String path: pathCandidates) {
            final File opt = new File(path);
            if (opt.isFile() && opt.canExecute()) {
                // http://peter.sh/experiments/chromium-command-line-switches/
                final List<String> commands = new ArrayList<String>();
                commands.add(path);
                BrowserUtils.addDefaultChromeArgs(commands);
                BrowserUtils.addAppWindowArgs(commands, this.windowWidth, 
                        this.windowHeight, uri);
                commands.add("--app=" + uri);
                return BrowserUtils.runProcess(commands);
            }
        }
        
        BrowserUtils.openSystemDefaultBrowser(uri);
        log.warn("Could not find chrome");
        return null;
    }
}
