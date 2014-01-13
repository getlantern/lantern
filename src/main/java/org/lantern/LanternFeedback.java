package org.lantern;

import java.util.Date;

import org.apache.commons.lang.StringUtils;
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
    private static final Logger LOG = LoggerFactory.getLogger(JsonUtils.class);
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
        LogglyMessage msg = new LogglyMessage(
                reporterId,
                "Lantern Feedback",
                new Date())
                .setExtraFromJson(json);
        loggly.log(msg);
    }
}
