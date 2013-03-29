package org.lantern;

import java.util.concurrent.atomic.AtomicInteger;

import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategy;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategyFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternXmppRetryStrategyFactory implements
        XmppConnectionRetyStrategyFactory {

    private static final Logger LOG = LoggerFactory
            .getLogger(LanternXmppRetryStrategyFactory.class);

    static class LanternXmppRetryStrategy implements XmppConnectionRetyStrategy {

        private final AtomicInteger retries = new AtomicInteger(0);

        @Override
        public boolean retry() {
            if (retries.get() < 100) {
                retries.incrementAndGet();
            }
            return true;
        }

        @Override
        public void sleep() {
            try {
                // logarithmic retry; from zero seconds to ~two minutes
                Thread.sleep(50 * 1000 * (long) Math.log(1 + this.retries.get() * 0.1));
            } catch (final InterruptedException e) {
                LOG.info("Interrupted?", e);
            }
        }

    }

    @Override
    public XmppConnectionRetyStrategy newStrategy() {
        return new LanternXmppRetryStrategy();
    }

}
