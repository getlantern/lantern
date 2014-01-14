package org.lantern;

import java.awt.Desktop;
import java.awt.Point;
import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.jna.platform.win32.Shell32Util;
import com.sun.jna.platform.win32.ShlObj;

public class ChromeRunner {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Point location;
    
    private volatile Process process;
    private final int screenWidth;
    private final int screenHeight;
    
    public ChromeRunner(final int screenWidth, final int screenHeight) {
        this.screenWidth = screenWidth;
        this.screenHeight = screenHeight;
        this.location = 
            LanternUtils.getScreenCenter(screenWidth, screenHeight);
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
        if (SystemUtils.IS_OS_MAC_OSX) {
            final File path1 = new File("install/osx/Lantern.app/Contents/MacOS/Lantern");
            if (path1.isFile() && path1.canExecute()) return path1.getAbsolutePath();
            final File path2 = new File("Lantern.app/Contents/MacOS/Lantern");
            if (path2.isFile() && path2.canExecute()) return path2.getAbsolutePath();
            log.warn("Could not find LanternBrowser");
            return null;
            //chrome is broken on os x -- see #622
            //return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
        } else if (SystemUtils.IS_OS_LINUX) {
            final ArrayList<String> path_candidates = new ArrayList<String>();
            path_candidates.add("/usr/bin/google-chrome");
            path_candidates.add("/usr/bin/google-chrome-stable");
            path_candidates.add("/usr/bin/google-chrome-unstable");
            path_candidates.add("/usr/bin/chromium");
            path_candidates.add("/usr/bin/chromium-browser");
            path_candidates.add("/usr/bin/google-chrome-beta");
            for (String path: path_candidates) {
                final File opt = new File(path);
                if (opt.isFile() && opt.canExecute()) return path;
            }
            log.warn("Could not find chrome");
            return null;
        } else if (SystemUtils.IS_OS_WINDOWS) {
            return findWindowsExe();
        } else {
            throw new UnsupportedOperationException(
                    "Unsupported OS: "+SystemUtils.OS_NAME);
        }
    }
    
    private void openSystemDefaultBrowser(String uri) {
        log.debug("Opening system default browser to: {}", uri);
        try {
            Desktop.getDesktop().browse(new URI(uri));
        } catch (Exception e) {
            log.error("Unable to browse to uri: {}", uri, e);
        }
    }
    
    private String findWindowsExe() {//final String... opts) {
        final Map<String, Integer> opts = new HashMap<String, Integer>();
        opts.put("APPDATA", ShlObj.CSIDL_APPDATA);
        opts.put("LOCALAPPDATA", ShlObj.CSIDL_LOCAL_APPDATA);
        opts.put("PROGRAMFILES", ShlObj.CSIDL_PROGRAM_FILES);
        opts.put("ProgramW6432", ShlObj.CSIDL_PROGRAM_FILESX86);
        final String chromePath = "/Google/Chrome/Application/chrome.exe";
        final Collection<String> paths = new HashSet<String>();
        for (final Entry<String, Integer> entry : opts.entrySet()) {
            final String base;
            final String envBase = System.getenv(entry.getKey());
            if (StringUtils.isBlank(envBase)) {
                base = Shell32Util.getFolderPath(entry.getValue().intValue());
            } else {
                base = envBase;
            }
            if (StringUtils.isBlank(base)) {
                log.error("Could not resolve env variable: {}", base);
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

    public void open() throws IOException {
        open(StaticSettings.getApiPort(), StaticSettings.getPrefix());
    }

    public void open(final int port, String prefix) throws IOException {

        if (this.process != null) {
            try {
                final int exitValue = this.process.exitValue();
                log.info("Got exit value from former process: ", exitValue);
            } catch (final IllegalThreadStateException e) {
                // This indicates the existing process is still running.
                log.info("Ignoring open call since process is still running");
                return;
            }
        }
        final String endpoint = StaticSettings.getLocalEndpoint(port, prefix);
        log.info("Opening browser to: {}", endpoint);
        final List<String> commands = new ArrayList<String>();
        final String executable = determineExecutable();
        if (executable == null) {
            String uri = StaticSettings.getLocalEndpoint(port, prefix)
                    + "/index.html";
            openSystemDefaultBrowser(uri);
        } else {
            commands.add(executable);
            if (SystemUtils.IS_OS_MAC_OSX) {
                commands.add(endpoint + "/index.html");
            } else {
                // http://peter.sh/experiments/chromium-command-line-switches/
                commands.add("--user-data-dir="
                        + LanternClientConstants.CONFIG_DIR.getAbsolutePath());
                commands.add("--window-size=" + screenWidth + "," + screenHeight);
                commands.add("--window-position=" + location.x + "," + location.y);
                commands.add("--disable-translate");
                commands.add("--disable-sync");
                commands.add("--no-default-browser-check");
                commands.add("--disable-metrics");
                commands.add("--disable-metrics-reporting");
                commands.add("--temp-profile");
                commands.add("--disable-plugins");
                commands.add("--disable-java");
                commands.add("--disable-extensions");
                commands.add("--no-default-browser-check");
                commands.add("--app=" + endpoint + "/index.html");
            }
    
            final ProcessBuilder processBuilder = new ProcessBuilder(commands);
    
            // Note we don't call waitFor on the process to avoid blocking the
            // calling thread and because we don't care too much about the return
            // value.
            this.process = processBuilder.start();
            
            new Analyzer(process.getInputStream());
            new Analyzer(process.getErrorStream());
        }
    }
    
    public void close() {
        log.info("Closing Chrome browser...process is: {}", this.process);
        if (this.process != null) {
            log.info("Really closing Chrome browser...");
            this.process.destroy();
            this.process = null;
        }
    }

    private class Analyzer implements Runnable {

        final InputStream is;

        public Analyzer(final InputStream is) {
            this.is = is;
            final Thread t = new Thread(this, "Browser-Process-Output-Thread");
            t.setDaemon(true);
            t.start();
        }

        @Override
        public void run() {
            BufferedReader br = null;
            try {
                br = new BufferedReader(new InputStreamReader(this.is, 
                    LanternConstants.UTF8));

                String line = "";
                while((line = br.readLine()) != null) {
                    System.out.println(line);
                }
            } catch (final IOException e) {
                log.info("Exception reading external process", e);
            } finally {
                IOUtils.closeQuietly(br);
            }
            
        }
    }
}
