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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ChromeRunner {

    private static final int SCREEN_WIDTH = 970;
    private static final int SCREEN_HEIGHT = 630;
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final ProcessBuilder processBuilder;
    private Process process;
    
    public ChromeRunner() throws IOException {
        this(LanternUtils.getScreenCenter(SCREEN_WIDTH, SCREEN_HEIGHT));
    }
    
    public ChromeRunner(final Point location) throws IOException {
        final List<String> commands = new ArrayList<String>();
        final String executable = determineExecutable();
        commands.add(executable);
        commands.add("--user-data-dir="+LanternConstants.CONFIG_DIR.getAbsolutePath());
        commands.add("--window-size="+SCREEN_WIDTH+","+SCREEN_HEIGHT);
        commands.add("--window-position="+location.x+","+location.y);
        commands.add("--app=http://localhost:"+RuntimeSettings.getApiPort());

        this.processBuilder = new ProcessBuilder(commands);
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
            return "/usr/bin/google-chrome";
        }
        /*
         * Should be something like:
         * 
         * Windows XP    %HOMEPATH%\Local Settings\Application Data\Google\Chrome\Application\chrome.exe
         * Windows Vista    C:\Users\%USERNAME%\AppData\Local\Google\Chrome\Application\chrome.exe
         */
        throw new UnsupportedOperationException("This is an experimental feature!");
    }

    public void open() throws InterruptedException, IOException {
        
        this.process = this.processBuilder.start();
        
        new Analyzer(process.getInputStream());
        new Analyzer(process.getErrorStream());
        final int result = process.waitFor();
    }
    
    public void close() {
        if (this.process != null) {
            this.process.destroy();
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
