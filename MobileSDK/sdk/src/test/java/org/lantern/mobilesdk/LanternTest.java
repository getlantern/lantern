package org.lantern.mobilesdk;

import org.junit.Test;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Scanner;

import static org.junit.Assert.*;


/**
 * To work on unit tests, switch the Test Artifact in the Build Variants view.
 */
public class LanternTest {
    private static final String IP_LOOKUP = "http://ipinfo.io/ip";

    @Test
    public void testOnAndOff() throws Exception {
        File configDir = File.createTempFile("temp", Long.toString(System.nanoTime()));
        if (!configDir.delete()) {
            throw new Exception("Unable to delete temp file");
        }
        if (!configDir.mkdir()) {
            throw new Exception("Unable to create directory");
        }

        String originalIP = fetchIP();
        Lantern.start(configDir.getAbsolutePath(), 15000);
        String proxiedIP = fetchIP();
        Lantern.stop();
        String unproxiedIP = fetchIP();
        assertEquals(originalIP, unproxiedIP);
        assertNotEquals(originalIP, proxiedIP);
    }

    private String fetchIP() throws Exception {
        URL url = new URL(IP_LOOKUP);
        HttpURLConnection urlConnection = (HttpURLConnection) url.openConnection();
        // Need to force closing so that old connections (with old proxy settings) don't get reused.
        urlConnection.setRequestProperty("Connection", "close");
        try {
            InputStream in = new BufferedInputStream(urlConnection.getInputStream());
            Scanner s = new Scanner(in).useDelimiter("\\A");
            return s.hasNext() ? s.next() : "";
        } finally {
            urlConnection.disconnect();
        }
    }
}