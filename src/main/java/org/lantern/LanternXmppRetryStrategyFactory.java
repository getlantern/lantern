package org.lantern;

import org.lantern.state.Model;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategy;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategyFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternXmppRetryStrategyFactory implements
        XmppConnectionRetyStrategyFactory {

    private static final Logger LOG = LoggerFactory
            .getLogger(LanternXmppRetryStrategyFactory.class);
    private final Model model;
    
    @Inject
    public LanternXmppRetryStrategyFactory(final Model model) {
        this.model = model;
    }
    
    private class LanternXmppRetryStrategy implements XmppConnectionRetyStrategy {

        @Override
        public boolean retry() {
            return true;
        }

        @Override
        public void sleep() {
            try {
                Thread.sleep(model.getS3Config().getSignalingRetryTime());
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
