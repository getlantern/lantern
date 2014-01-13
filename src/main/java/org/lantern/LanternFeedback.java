package org.lantern;

import java.io.IOException;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.io.FileSystemUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.lantern.loggly.Loggly;
import org.lantern.loggly.LogglyMessage;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternFeedback {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private Model model;
    private Loggly loggly;

    @Inject
    public LanternFeedback(Model model) {
        this.model = model;
        this.loggly = new Loggly(model.isDev(),
             model.getSettings().getMode() == Mode.get ?
             LanternConstants.LANTERN_LOCALHOST_ADDR :
             null);
    }

    public void submit(String json) {
        String reporterId = model.getProfile().getEmail();
        if (StringUtils.isBlank(reporterId)) {
            reporterId = model.getInstanceId();
        }
        LogglyMessage msg = new LogglyMessage(reporterId, json, new Date());
        loggly.log(msg);
        /*
        final Map <String, String> feedback = new HashMap<String, String>(); 
        feedback.putAll(systemInfo());
        feedback.put("message", message);
        feedback.put("replyto", replyTo == null ? "" : replyTo);
        */
    }

    // TODO merge this with model.system
    protected Map<String, String> systemInfo() {
        final Map<String, String> info = new HashMap<String,String>();

        info.put("lanternVersion", LanternClientConstants.VERSION);        
        info.put("javaVersion", SystemUtils.JAVA_VERSION);
        info.put("osName", SystemUtils.OS_NAME);
        info.put("osArch", SystemUtils.OS_ARCH);
        info.put("osVersion", SystemUtils.OS_VERSION);
        info.put("language", SystemUtils.USER_LANGUAGE);
        info.put("country", SystemUtils.USER_COUNTRY);
        info.put("timeZone", SystemUtils.USER_TIMEZONE);
        
        final String osRoot = SystemUtils.IS_OS_WINDOWS ? "c:" : "/";
        long free = Long.MAX_VALUE;
        try {
            free = FileSystemUtils.freeSpaceKb(osRoot);
            // Convert to megabytes for easy reading.
            free = free / 1024L;
        } catch (final IOException e) {
        }
        info.put("diskSpace", String.valueOf(free));
        return info;
    }
    
}
