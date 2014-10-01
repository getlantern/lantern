package org.lantern.papertrail;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.Socket;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashSet;

import javax.net.SocketFactory;

import org.apache.commons.lang3.SystemUtils;
import org.apache.log4j.Appender;
import org.apache.log4j.AppenderSkeleton;
import org.apache.log4j.Layout;
import org.apache.log4j.spi.LocationInfo;
import org.apache.log4j.spi.LoggingEvent;
import org.lantern.Censored;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.ProxySocketFactory;
import org.lantern.state.Model;

/**
 * An {@link Appender} that logs to {@link Papertrail}.
 */
public class PapertrailAppender extends AppenderSkeleton {

    private final Collection<LogData> recentLogs =
            Collections.synchronizedSet(new LinkedHashSet<LogData>());

    public static final String PAPERTRAIL_HOST = "logs2.papertrailapp.com";
    private static final int PAPERTRAIL_PORT = 35884;

    private final Model model;
    private final Papertrail papertrail;

    public PapertrailAppender(Model model,
            final ProxySocketFactory proxied,
            final Censored censored,
            Layout layout) {
        this.model = model;
        this.setLayout(layout);
        papertrail = new Papertrail(PAPERTRAIL_HOST, PAPERTRAIL_PORT) {
            @Override
            protected Socket newPlainTextSocket() throws Exception {
                if (censored.isCensored() || LanternUtils.isGet()) {
                    return proxied.createSocket(PAPERTRAIL_HOST,
                            PAPERTRAIL_PORT);
                } else {
                    return SocketFactory.getDefault().createSocket(
                            PAPERTRAIL_HOST,
                            PAPERTRAIL_PORT);
                }
            }
        };
    }

    @Override
    protected void append(LoggingEvent event) {
        if (!model.getSettings().isAutoReport()) {
            // Don't report anything if the user doesn't have it turned on.
            return;
        }
        final LocationInfo li = event.getLocationInformation();
        final LogData logData = new LogData(li);
        if (recentLogs.contains(logData)) {
            // Don't send duplicates to avoid hammering the server.
            return;
        }
        synchronized (this.recentLogs) {
            // Remove the oldest bug if necessary.
            if (this.recentLogs.size() >= 200) {
                final LogData lastIn = this.recentLogs.iterator().next();
                this.recentLogs.remove(lastIn);
            }
            recentLogs.add(logData);
        }

        StringWriter message = new StringWriter();
        // Start each line of the message off with a prefix that gives some
        // metadata
        final String prefix = String.format(
                "Lantern Client (%1$s / %2$s / %3$s / %4$s / %5$s) - %6$-5s ",
                model.getInstanceId(),
                model.getLocation().getCountry(),
                SystemUtils.OS_NAME,
                LanternClientConstants.VERSION,
                SystemUtils.JAVA_RUNTIME_VERSION,
                event.getLevel());
        message.append(prefix);
        message.append(this.getLayout().format(event));
        if (event.getThrowableInformation() != null) {
            PrintWriter writer = new PrintWriter(message) {
                @Override
                public void write(String s) {
                    super.write(prefix);
                    super.write(s);
                }
            };
            event.getThrowableInformation().getThrowable()
                    .printStackTrace(writer);
            writer.close();
        }
        papertrail.log(message.toString());
    }

    @Override
    public boolean requiresLayout() {
        return true;
    }

    @Override
    public void close() {
        // do nothing
    }

    private static final class LogData {

        private final String className;
        private final String methodName;
        private final String lineNumber;

        private LogData(final LocationInfo li) {
            this.className = li.getClassName();
            this.methodName = li.getMethodName();
            this.lineNumber = li.getLineNumber();
        }

        @Override
        public int hashCode() {
            final int PRIME = 31;
            int result = 1;
            result = PRIME * result
                    + ((className == null) ? 0 : className.hashCode());
            result = PRIME * result
                    + ((lineNumber == null) ? 0 : lineNumber.hashCode());
            result = PRIME * result
                    + ((methodName == null) ? 0 : methodName.hashCode());
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
            final LogData other = (LogData) obj;
            if (className == null) {
                if (other.className != null)
                    return false;
            } else if (!className.equals(other.className))
                return false;
            if (lineNumber == null) {
                if (other.lineNumber != null)
                    return false;
            } else if (!lineNumber.equals(other.lineNumber))
                return false;
            if (methodName == null) {
                if (other.methodName != null)
                    return false;
            } else if (!methodName.equals(other.methodName))
                return false;
            return true;
        }
    }

}
