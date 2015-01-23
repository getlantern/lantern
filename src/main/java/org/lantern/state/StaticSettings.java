package org.lantern.state;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.security.SecureRandom;
import java.util.Properties;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.littleshoot.proxy.impl.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class StaticSettings {

    private static final Logger LOG = LoggerFactory
            .getLogger(StaticSettings.class);

    private static String prefix;
    private static final int API_PORT;

    private static final File constantsFile = new File(
            LanternClientConstants.CONFIG_DIR, "serverAddress");

    static {
        API_PORT = loadSettings();
    }

    private static int loadSettings() {
        final Properties props = new Properties();
        if (constantsFile.isFile()) {
            InputStream is = null;
            try {
                is = new FileInputStream(constantsFile);
                props.load(is);
                prefix = props.getProperty("prefix");
                return Integer.parseInt(props.getProperty("port"));
            } catch (final IOException e) {
                LOG.error("Could not load settings file at"
                        + constantsFile.getAbsolutePath());
                e.printStackTrace();
            } finally {
                IOUtils.closeQuietly(is);
            }
        } 
        //need to generate the file
        return createPropertiesFile();
    }

    /**
     * During the install process, we need to generate a random
     * port and prefix
     * 
     * @return  The port we're using.
     */
    private static int createPropertiesFile() {
        final Properties props = new Properties();
        final byte[] bytes = new byte[16];
        new SecureRandom().nextBytes(bytes);
        final String randomPrefix = Base64.encodeBase64URLSafeString(bytes);

        prefix = "/" + randomPrefix;
        final int tempPort = LanternUtils.randomPort();

        props.put("port", "" + tempPort);
        props.put("prefix", prefix);

        OutputStream os = null;
        try {
            os = new FileOutputStream(constantsFile);
            props.store(os, "Randomly generated port/prefix settings");
            prefix = props.getProperty("prefix");
        } catch (final IOException e) {
            LOG.error("Could not save settings file at {}", constantsFile);
        } finally {
            IOUtils.closeQuietly(os);
        }
        return tempPort;
    }

    public static int getApiPort() {
        return API_PORT;
    }

    public static String getLocalEndpoint() {
        return getLocalEndpoint(API_PORT, prefix);
    }

    public static String getLocalEndpoint(final int port, String prefix) {
        return getEndpoint("127.0.0.1", port, prefix);
    }
    
    public static String getNetworkEndpoint() {
        try {
            return getEndpoint(NetworkUtils.getLocalHost().getHostAddress(),
                    API_PORT, prefix);
        } catch (final UnknownHostException e) {
            LOG.error("Could not get local network address", e);
            return "";
        }
    }

    private static String getEndpoint(final String address, final int port,
            final String prefix) {
        return "http://" + address + ":" + port + prefix;
    }

    public static String getPrefix() {
        return prefix;
    }
}
