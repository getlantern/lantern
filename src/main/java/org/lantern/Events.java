package org.lantern;

import java.util.concurrent.Executors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.AsyncEventBus;
import com.google.common.eventbus.EventBus;
import com.google.common.util.concurrent.ThreadFactoryBuilder;

public class Events {

    private static final Logger LOG = LoggerFactory.getLogger(Events.class);
    
    private static final EventBus eventBus = new EventBus();

    private static final AsyncEventBus asyncEventBus =
        new AsyncEventBus("Async-Event-Bus", Executors.newCachedThreadPool(
            new ThreadFactoryBuilder().setDaemon(true).setNameFormat(
                "Async-Event-Thread-%d").build()));

    public static void register(final Object toRegister) {
        asyncEventBus.register(toRegister);
        eventBus.register(toRegister);
    }
    
    
    public static EventBus eventBus() {
        return eventBus;
    }

    public static AsyncEventBus asyncEventBus() {
        return asyncEventBus;
    }
}
