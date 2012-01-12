package org.lantern;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Adapted from Dem Pilafian's public domain BareBonesBrowserLaunch.
 */
public class LinuxBrowserLaunch {

    private static final Logger LOG = 
        LoggerFactory.getLogger(LinuxBrowserLaunch.class);
    
    private static final String[] browsers = { "google-chrome", "firefox", "opera",
       "epiphany", "konqueror", "conkeror", "midori", "kazehakase", "mozilla" };

    public static void openURL(final String url) {
        String browser = null;
        for (final String b : browsers)
            try {
                if (browser == null && seemsToHaveBrowser(b)) {
                    Runtime.getRuntime().exec(new String[] {browser = b, url});
                }
            } catch (final IOException e) {
                LOG.info("Exception attempting to launch "+b, e);
            }
        if (browser == null) {
            LOG.info("Could not launch browser!!");
        }
    }

    private static boolean seemsToHaveBrowser(final String browser) {
        try {
            return Runtime.getRuntime().exec(
                new String[] { "which", browser }).getInputStream().read() != -1;
        } catch (final IOException e) {
            return false;
        }
    }

}