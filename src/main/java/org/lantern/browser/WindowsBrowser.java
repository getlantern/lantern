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
import org.lantern.LanternUtils;
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
        final String executable = determineExecutable();
        if (StringUtils.isBlank(executable)) {
            // At this point we've effectively only searched for Chrome and
            // have not found it. If the user has firefox, though, we should
            // use it. This checks that. Note this is windows only!
            if (LanternUtils.firefoxIsDefaultBrowser()) {
                BrowserUtils.openSystemDefaultBrowser(uri);
            } else {
                // This will trigger a message telling the user they need
                // to install Chrome.
                throw new UnsupportedOperationException("Could not find Chrome!");
            }
        }
        final List<String> commands = new ArrayList<String>();
        commands.add(executable);
        BrowserUtils.addDefaultChromeArgs(commands, this.windowWidth, 
                this.windowHeight);
        commands.add("--app=" + uri);
        
        return BrowserUtils.runProcess(commands);
    }

    private String determineExecutable() throws IOException {
        final String path = determineExecutablePath();
        if (path == null) {
            return null;
        }
        final File file = new File(path);
        if (!file.isFile()) {
            throw new IOException("Could not find chrome at:" + path);
        } else if (!file.canExecute()) {
            throw new IOException("Chrome not executable at:" + path);
        }
        return path;
    }

    private String determineExecutablePath() {
        final Map<String, Integer> opts = new LinkedHashMap<String, Integer>();
        opts.put("APPDATA", ShlObj.CSIDL_APPDATA);
        opts.put("LOCALAPPDATA", ShlObj.CSIDL_LOCAL_APPDATA);
        opts.put("PROGRAMFILES", ShlObj.CSIDL_PROGRAM_FILES);
        opts.put("ProgramW6432", ShlObj.CSIDL_PROGRAM_FILESX86);
        final String chromePath = "/Google/Chrome/Application/chrome.exe";
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
            final String path = base + chromePath;
            paths.add(path);
            final File candidate = new File(path);
            if (candidate.isFile() && candidate.canExecute()) {
                log.debug("Running with path: {}", path);
                return path;
            }
        }
        
        final String msg = 
                "Could not find Chrome on Windows!! Searched paths:\n"+paths;
        log.warn(msg);
        return null;
    }
}
