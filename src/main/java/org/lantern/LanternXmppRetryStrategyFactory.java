package org.lantern;

import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategy;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategyFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternXmppRetryStrategyFactory implements
        XmppConnectionRetyStrategyFactory {

    private static final Logger LOG = LoggerFactory
            .getLogger(LanternXmppRetryStrategyFactory.class);

    static class LanternXmppRetryStrategy implements XmppConnectionRetyStrategy {

        @Override
        public boolean retry() {
            return true;
        }

        @Override
        public void sleep() {
            try {
                //fixed retry strategy -- just wait two seconds
                Thread.sleep(2000);
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
