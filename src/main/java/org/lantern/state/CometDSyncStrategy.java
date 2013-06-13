package org.lantern.state;

import java.util.Arrays;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ServerSession;
import org.lantern.JsonUtils;
import org.lantern.event.SyncType;
import org.lantern.state.Model.Run;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 * Strategy for syncing/pushing with the browser using cometd.
 */
@Singleton
public class CometDSyncStrategy implements SyncStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final Executor exec = Executors.newSingleThreadExecutor(new ThreadFactory() {

        @Override
        public Thread newThread(final Runnable r) {
            final Thread t = new Thread(r, "Sync-Exec-Thread");
            t.setDaemon(true);
            return t;
        }
    });

    @Override
    public void sync(final ServerSession session, final SyncType op, final String path, final Object value) {
        log.info("SYNCING");
        if (session == null) {
            log.info("No session...not syncing");
            return;
        }

        // We send all updates over the same channel.
        final ClientSessionChannel ch =
            session.getLocalSession().getChannel("/sync");

        final SyncData data = new SyncData(op.toString().toLowerCase(), path, value);
        final List<SyncData> ops = Arrays.asList(data);
        final String json = JsonUtils.jsonify(ops, Run.class);

        if (!path.equals(SyncPath.ROSTER.getPath())) {
            log.debug("Sending state to frontend:\n{}", json);
            log.debug("Synced object: {}", value);
        } else {
            log.debug("SYNCING ROSTER -- NOT LOGGING FULL");
            log.debug("Sending state to frontend:\n{}", json);
        }
        this.exec.execute(new Runnable() {
            @Override
            public void run() {
                ch.publish(ops);
                log.debug("Sync performed");
            }
        });
    }

    /**
     * Helper class that formats data according to:
     *
     * https://github.com/getlantern/lantern-ui/blob/master/SPECS.md
     */
    public static class SyncData {
        private final String op;
        private final String path;
        private final Object value;

        public SyncData(final String op, final SyncPath channel, final Object val) {
            this(op, channel.getPath(), val);
        }

        public SyncData(final String op, final String path, final Object val) {
            this.op = op;
            if (path.length() > 0)
                this.path = "/" + path;
            else
                this.path = path;
            this.value = val;
        }

        public String getPath() {
            return path;
        }

        public Object getValue() {
            return value;
        }

        public String getOp() {
            return op;
        }
    }

}
