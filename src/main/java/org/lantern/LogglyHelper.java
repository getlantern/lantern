package org.lantern;

import java.util.Date;

import javax.net.ssl.SSLContext;

import org.apache.commons.lang.StringUtils;
import org.lantern.HttpURLClient.SSLContextSource;
import org.lantern.loggly.Loggly;
import org.lantern.loggly.LogglyMessage;
import org.lantern.state.Mode;
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
    private final Model model;
    private final Loggly loggly;

    @Inject
    public LogglyHelper(Model model, final LanternTrustStore trustStore) {
        this.model = model;
        this.loggly = new Loggly(
             LanternUtils.isDevMode(),
             model.getSettings().getMode() == Mode.get ?
             LanternConstants.LANTERN_LOCALHOST_ADDR :
             null);
        loggly.setSslContextSource(new SSLContextSource() {
            @Override
            public SSLContext getContext(String url) {
                return trustStore.getCumulativeSslContext();
            }
        });

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
