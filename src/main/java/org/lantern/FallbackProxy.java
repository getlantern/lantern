package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;

public class FallbackProxy {
    private static final Logger LOG = LoggerFactory.getLogger(FallbackProxy.class);
    private static final AtomicBoolean CONFIGURATION_READ = new AtomicBoolean();
    private static final AtomicBoolean IS_CONFIGURED = new AtomicBoolean();

    private String ip;
    
    private int port;
    
    private String auth_token;
    
    private String protocol;

    public FallbackProxy() {}

    public FallbackProxy(final String ip, final int port) {
        this.ip = ip;
        this.port = port;
    }
    
    /**
     * Reads the configured FallbackProxy from disk.
     * 
     * @return
     */
    synchronized public static FallbackProxy readConfigured() {
        try {
            copyFallbackFile();
        } catch (final IOException e) {
            LOG.warn("Could not copy fallback?", e);
        }
        CONFIGURATION_READ.set(true);
        final File file = new File(LanternClientConstants.CONFIG_DIR,
                "fallback.json");
        if (!file.isFile()) {
            LOG.error("No fallback proxy to load!");
            return null;
        }

        final ObjectMapper om = new ObjectMapper();
        InputStream is = null;
        try {
            is = new FileInputStream(file);
            final String proxy = IOUtils.toString(is);
            final FallbackProxy fp = om.readValue(proxy, FallbackProxy.class);
            return fp;
        } catch (final IOException e) {
            LOG.error("Could not load fallback", e);
            return null;
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    
    public static boolean isConfigured() {
        if (!CONFIGURATION_READ.get()) {
            FallbackProxy configured = readConfigured();
            IS_CONFIGURED.set(configured != null);
        }
        return IS_CONFIGURED.get();
    }

    public String getIp() {
        return ip;
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }
    
    public String getAuth_token() {
        return auth_token;
    }
    
    public void setAuth_token(String auth_token) {
        this.auth_token = auth_token;
    }
    
    public String getProtocol() {
        return protocol;
    }
    
    public void setProtocol(String protocol) {
        this.protocol = protocol;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((auth_token == null) ? 0 : auth_token.hashCode());
        result = prime * result + ((ip == null) ? 0 : ip.hashCode());
        result = prime * result + port;
        result = prime * result
                + ((protocol == null) ? 0 : protocol.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        FallbackProxy other = (FallbackProxy) obj;
        if (auth_token == null) {
            if (other.auth_token != null)
                return false;
        } else if (!auth_token.equals(other.auth_token))
            return false;
        if (ip == null) {
            if (other.ip != null)
                return false;
        } else if (!ip.equals(other.ip))
            return false;
        if (port != other.port)
            return false;
        if (protocol == null) {
            if (other.protocol != null)
                return false;
        } else if (!protocol.equals(other.protocol))
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "FallbackProxy [ip=" + ip + ", port=" + port + ", auth_token="
                + auth_token + ", protocol=" + protocol + "]";
        
    }

    private static void copyFallbackFile() throws IOException {
        LOG.debug("Copying fallback file");
        final File from;

        final File cur = new File(new File(SystemUtils.USER_HOME),
                "fallback.json");
        if (cur.isFile()) {
            from = cur;
        } else {
            LOG.debug("No fallback proxy found in home - checking runtime user.dir...");
            final File home = new File(new File(SystemUtils.USER_DIR),
                    "fallback.json");
            if (home.isFile()) {
                from = home;
            } else {
                LOG.warn("Still could not find fallback proxy!");
                return;
            }
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, from.getName());
        if (!par.isDirectory() && !par.mkdirs()) {
            throw new IOException("Could not make config dir?");
        }
        LOG.debug("Copying from {} to {}", from, to);
        Files.copy(from, to);
    }
}
