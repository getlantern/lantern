package org.lantern.papertrail;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.Socket;

import javax.net.SocketFactory;

import org.apache.commons.lang3.SystemUtils;
import org.apache.log4j.Appender;
import org.apache.log4j.AppenderSkeleton;
import org.apache.log4j.Layout;
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
    private static final String PAPERTRAIL_HOST = "logs2.papertrailapp.com";
    private static final int PAPERTRAIL_PORT = 22762;

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
        StringWriter message = new StringWriter();
        // Start the message off with a prefix that gives some metadata
        message.append(String.format(
                "Lantern Client (%1$s / %2$s / %3$s / %4$s) - %5$s",
                model.getInstanceId(),
                model.getLocation().getCountry(),
                SystemUtils.OS_NAME,
                LanternClientConstants.VERSION,
                message));
        message.append(this.getLayout().format(event));
        if (event.getThrowableInformation() != null) {
            PrintWriter writer = new PrintWriter(message);
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

}
