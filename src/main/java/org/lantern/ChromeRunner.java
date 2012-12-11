package org.lantern;

import java.awt.Point;
import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
            return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
        } else if (SystemUtils.IS_OS_LINUX) {
            final String path1 = "/usr/bin/google-chrome";
            final File opt1 = new File(path1);
            if (opt1.isFile()) return path1;
            
            // TODO: Clean this up across OSes.
            return "/usr/bin/chromium-browser";
        } else if (SystemUtils.IS_OS_WINDOWS_XP) {
            final String ad = System.getenv("APPDATA");
            return ad + "/Google/Chrome/Application/chrome.exe";
        } else if (SystemUtils.IS_OS_WINDOWS) {
            final String ad = System.getenv("APPDATA");
            return ad + "/Local/Google/Chrome/Application/chrome.exe";
        }
        /*
         * Should be something like:
         * 
         * Windows XP    %HOMEPATH%\Local Settings\Application Data\Google\Chrome\Application\chrome.exe
         * Windows Vista    C:\Users\%USERNAME%\AppData\Local\Google\Chrome\Application\chrome.exe
         */
        throw new UnsupportedOperationException("This is an experimental feature!");
    }

    public void open() throws IOException {
        open(StaticSettings.getApiPort());
    }
    
    public void open(final int port) throws IOException {

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
        final String endpoint = StaticSettings.getLocalEndpoint(port);
        log.debug("Opening browser to: {}", endpoint);
        final List<String> commands = new ArrayList<String>();
        final String executable = determineExecutable();
        commands.add(executable);
        commands.add("--user-data-dir="+LanternConstants.CONFIG_DIR.getAbsolutePath());
        commands.add("--window-size="+screenWidth+","+screenHeight);
        commands.add("--window-position="+location.x+","+location.y);
        commands.add("--app="+endpoint);

        final ProcessBuilder processBuilder = new ProcessBuilder(commands);
        
        // Note we don't call waitFor on the process to avoid blocking the
        // calling thread and because we don't care too much about the return
        // value.
        this.process = processBuilder.start();
        
        new Analyzer(process.getInputStream());
        new Analyzer(process.getErrorStream());
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
            final Thread t = new Thread(this);
            t.setDaemon(true);
            t.start();
        }

        @Override
        public void run() {
            BufferedReader br = null;
            try {
                br = new BufferedReader(new InputStreamReader(this.is));

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
