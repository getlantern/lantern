package org.lantern.loggly;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.lang3.SystemUtils;
import org.apache.commons.lang3.math.NumberUtils;
import org.apache.log4j.Appender;
import org.apache.log4j.AppenderSkeleton;
import org.apache.log4j.spi.LocationInfo;
import org.apache.log4j.spi.LoggingEvent;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.loggly.Loggly;
import org.lantern.loggly.LogglyMessage;
import org.lantern.state.Model;

/**
 * An {@link Appender} that logs to {@link Loggly}.
 */
public class LogglyAppender extends AppenderSkeleton {
    private final Model model;
    private final Loggly loggly;

    public LogglyAppender(Model model, boolean inTestMode) {
        this.model = model;
        loggly = new Loggly(inTestMode,
                LanternConstants.LANTERN_LOCALHOST_ADDR);
    }

    @Override
    protected void append(LoggingEvent event) {
        if (!model.getSettings().isAutoReport()) {
            // Don't report anything if the user doesn't have it turned on.
            return;
        }
        String messageString = event.getMessage() != null ? event.getMessage()
                .toString() : null;
        LogglyMessage message = new LogglyMessage(
                model.getInstanceId(),
                messageString,
                new Date(event.getTimeStamp())).sanitized();
        if (event.getThrowableInformation() != null) {
            message.setThrowable(event.getThrowableInformation().getThrowable());
        }
        final LocationInfo li = event.getLocationInformation();
        final int lineNumber;
        final String ln = li.getLineNumber();
        if (NumberUtils.isNumber(ln)) {
            lineNumber = Integer.parseInt(ln);
        } else {
            lineNumber = -1;
        }
        message.setLocationInfo(li.fullInfo);
        Map<String, Object> extra = new HashMap<String, Object>();
        extra.put("logLevel", event.getLevel().toString());
        extra.put("methodName", li.getMethodName());
        extra.put("lineNumber", lineNumber);
        extra.put("threadName", event.getThreadName());
        extra.put("javaVersion", SystemUtils.JAVA_VERSION);
        extra.put("osName", SystemUtils.OS_NAME);
        extra.put("osArch", SystemUtils.OS_ARCH);
        extra.put("osVersion", SystemUtils.OS_VERSION);
        extra.put("language", SystemUtils.USER_LANGUAGE);
        extra.put("country", SystemUtils.USER_COUNTRY);
        extra.put("timeZone", SystemUtils.USER_TIMEZONE);
        extra.put("fallback", LanternUtils.isFallbackProxy());
        extra.put("version", LanternClientConstants.VERSION);
        message.setExtra(extra);
        loggly.log(message);
    }

    @Override
    public boolean requiresLayout() {
        return false;
    }

    @Override
    public void close() {
        // do nothing
    }

}
