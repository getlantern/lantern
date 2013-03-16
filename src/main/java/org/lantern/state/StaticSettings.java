package org.lantern.state;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.SecureRandom;
import java.util.Properties;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class StaticSettings {

    private static final Logger LOG = LoggerFactory
            .getLogger(StaticSettings.class);

    private static String prefix;
    private static int port;

    public static final File constantsFile = new File(
            LanternClientConstants.CONFIG_DIR, "serverAddress");

    static {
        loadSettings();
    }

    private static void loadSettings() {
        Properties props = new Properties();
        if (constantsFile.isFile()) {
            InputStream is = null;
            try {
                is = new FileInputStream(constantsFile);
                props.load(is);
                prefix = props.getProperty("prefix");
                port = Integer.parseInt(props.getProperty("port"));
            } catch (final IOException e) {
                System.err.println("Could not load settings file at"
                        + constantsFile.getAbsolutePath());
                e.printStackTrace();
            } finally {
                IOUtils.closeQuietly(is);
            }
        } else {
            //need to generate the file
            createPropertiesFile();
        }
    }

    /**
     * During the install process, we need to generate a random
     * port and prefix
     */
    private static void createPropertiesFile() {
        Properties props = new Properties();
        byte[] bytes = new byte[16];
        new SecureRandom().nextBytes(bytes);
        String randomPrefix = Base64.encodeBase64URLSafeString(bytes);

        prefix = "/" + randomPrefix;
        port = LanternUtils.randomPort();

        props.put("port", "" + port);
        props.put("prefix", prefix);

        OutputStream is = null;
        try {
            is = new FileOutputStream(constantsFile);
            props.store(is, "Randomly generated port/prefix settings");
            prefix = props.getProperty("prefix");
            port = Integer.parseInt(props.getProperty("port"));
        } catch (final IOException e) {
            System.err.println("Could not save settings file at"
                    + constantsFile.getAbsolutePath());
            e.printStackTrace();
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    public static int getApiPort() {
        return port;
    }

    public static String getLocalEndpoint() {
        return getLocalEndpoint(port, prefix);
    }

    public static String getLocalEndpoint(final int port, String prefix) {
        return "http://127.0.0.1:" + port + prefix;
    }

    public static String getPrefix() {
        return prefix;
    }
}
