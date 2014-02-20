package org.lantern;

import java.util.Date;

import org.apache.commons.lang.StringUtils;
import org.lantern.loggly.Loggly;
import org.lantern.loggly.LogglyMessage;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Helper class for submitting messages to Loggly on behalf of the user when
 * the user submits feedback through the UI.
 */
@Singleton
public class LogglyHelper {
    private static final Logger LOG = LoggerFactory.getLogger(JsonUtils.class);
    private Model model;
    private Loggly loggly;

    @Inject
    public LogglyHelper(Model model) {
        this.model = model;
        this.loggly = new Loggly(
             LanternUtils.isDevMode(),
             LanternConstants.LANTERN_LOCALHOST_ADDR);
    }

    public void submit(String json) {
        String reporterId = "(" + model.getInstanceId() + ")";
        String email = model.getProfile().getEmail();
        if (!StringUtils.isBlank(email)) {
            reporterId = email + " " + reporterId;
        }
        LogglyMessage msg = new LogglyMessage(
                reporterId,
                "Lantern Feedback",
                new Date())
                .setExtraFromJson(json)
                .sanitized(false);
        loggly.log(msg);
        LOG.info("submitted to Loggly: %s", json);
    }
}
