package org.lantern.browser;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.jna.platform.win32.Shell32Util;
import com.sun.jna.platform.win32.ShlObj;
import com.sun.jna.platform.win32.Win32Exception;

/**
 * Opens the Lantern UI in a browser on Windows.
 */
public class WindowsBrowser implements LanternBrowser {
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final int windowWidth;
    private final int windowHeight;
    
    public WindowsBrowser(final int windowWidth, final int windowHeight) {
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
    }

    public Process open(final String uri) throws IOException {    
        final List<String> commands = new ArrayList<String>();
        final String chromePath = determineExecutablePath("/Google/Chrome/Application/chrome.exe");
        if (StringUtils.isBlank(chromePath)) {
            log.debug("Looking for firefox...");
            final String ffPath = determineExecutablePath("/Mozilla Firefox/firefox.exe");
            if (StringUtils.isNotBlank(ffPath)) {
                commands.add(ffPath);
                commands.add(uri);
                BrowserUtils.runProcess(commands);
                
                // We don't return the process on Firefox because it's a real
                // browser window the user could have other tabs open in.
                return null;
            }
        } else {
            commands.add(chromePath);
            BrowserUtils.addDefaultChromeArgs(commands);
            BrowserUtils.addAppWindowArgs(commands, windowWidth, windowHeight, uri);
            log.info("Running with commands: {}", commands);
            return BrowserUtils.runProcess(commands);
        }

        
        // At this point we've searched for Chrome and Firefox but have not found 
        // either. It's always possible either exists but in another location,
        // so check if they're the default and launch if they are. This has the 
        // downside of the browser window not getting killed when Lantern
        // shuts down because we don't know the process ID.
        if (BrowserUtils.firefoxOrChromeIsDefaultBrowser()) {
            BrowserUtils.openSystemDefaultBrowser(uri);
            return null;
        } else {
            // This will trigger a message telling the user they need
            // to install Chrome.
            throw new UnsupportedOperationException("Could not find Chrome or Firefox!");
        }
    }

    private String determineExecutablePath(final String subpath) {
        final Map<String, Integer> opts = new LinkedHashMap<String, Integer>();
        opts.put("APPDATA", ShlObj.CSIDL_APPDATA);
        opts.put("LOCALAPPDATA", ShlObj.CSIDL_LOCAL_APPDATA);
        opts.put("PROGRAMFILES", ShlObj.CSIDL_PROGRAM_FILES);
        opts.put("ProgramW6432", ShlObj.CSIDL_PROGRAM_FILESX86);
        final Collection<String> paths = new HashSet<String>();
        for (final Entry<String, Integer> entry : opts.entrySet()) {
            final String envvar = entry.getKey();
            String base;
            final String envBase = System.getenv(envvar);
            if (StringUtils.isBlank(envBase)) {
                try {
                    base = Shell32Util.getFolderPath(entry.getValue().intValue());
                } catch (Win32Exception we) {
                    // This means that we couldn't find the executable
                    base = null;
                }
            } else {
                base = envBase;
            }
            if (StringUtils.isBlank(base)) {
                log.error("Could not resolve env variable: {}", envvar);
                continue;
            }
            final String path = base + subpath;
            paths.add(path);
            final File candidate = new File(path);
            if (candidate.isFile() && candidate.canExecute()) {
                log.debug("Running with path: {}", path);
                return path;
            }
        }
        
        final String msg = 
                "Could not find browser on Windows!! Searched paths:\n"+paths;
        log.warn(msg);
        return null;
    }
}
