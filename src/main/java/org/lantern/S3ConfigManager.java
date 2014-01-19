package org.lantern;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.HttpResponse;
import org.codehaus.jackson.map.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.google.common.io.Files;

import org.lantern.util.HttpClientFactory;


public class S3ConfigManager {

    private static final Logger log
        = LoggerFactory.getLogger(S3ConfigManager.class);

    private static final String CONFIGURL_FILENAME = "configurl.txt";

    private String url;

    public S3ConfigManager() {
        try {
            copyConfigUrlFile();
        } catch (final IOException e) {
            log.warn("Couldn't copy config URL file?", e);
        }

        File file = new File(LanternClientConstants.CONFIG_DIR,
                             CONFIGURL_FILENAME);
        if (file.isFile()) {
            try {
                String folder = FileUtils.readFileToString(file, "UTF-8");
                url = LanternConstants.S3_CONFIG_BASE_URL
                                 + folder
                                 + "/config.json";
                log.info("Config URL is " + url);
            } catch (IOException e) {
                log.error("Couldn't read config URL file?", e);
            }
        } else {
            log.error("No config URL file?");
        }
    }

    public void testHttp() {
        HttpClient client = HttpClientFactory.newDirectClient();
        HttpGet get = new HttpGet(url);
        ObjectMapper om = new ObjectMapper();
        InputStream is = null;
        try {
            HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            String cfgStr = IOUtils.toString(is);
            S3Config cfg = om.readValue(cfgStr, S3Config.class);
            log.info("Serial number: " + cfg.getSerial_no());
            log.info("Controller: " + cfg.getController());
            log.info("Minimum poll time: " + cfg.getMinpoll());
            log.info("Maximum poll time: " + cfg.getMaxpoll());
            for (FallbackProxy fp : cfg.getFallbacks()) {
                log.info("Proxy: " + fp);
            }
        } catch (Exception e) {
            log.error("Couldn't fetch config: " + e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    private static void copyConfigUrlFile() throws IOException {
        log.debug("Copying config URL file");
        final File from;

        final File cur = new File(new File(SystemUtils.USER_HOME),
                                  CONFIGURL_FILENAME);
        if (cur.isFile()) {
            from = cur;
        } else {
            log.debug("No config URL file found in home"
                      + " - checking runtime user.dir...");
            final File home = new File(new File(SystemUtils.USER_DIR),
                                       CONFIGURL_FILENAME);
            if (home.isFile()) {
                from = home;
            } else {
                log.warn("Still could not find config URL file!");
                return;
            }
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, from.getName());
        if (!par.isDirectory() && !par.mkdirs()) {
            throw new IOException("Could not make config dir?");
        }
        log.debug("Copying from {} to {}", from, to);
        Files.copy(from, to);
    }
}
