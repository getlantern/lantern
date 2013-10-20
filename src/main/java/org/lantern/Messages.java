package org.lantern;

import static org.lantern.Tr.tr;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;
import org.lantern.state.Notification.MessageType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;

/**
 * Utility class for showing messages to the user.
 */
public class Messages {
    
    private static final int DEFAULT_DISPLAY_TIME = 30;
    private static final Logger LOG = 
            LoggerFactory.getLogger(Messages.class);
    private final Model model;

    @Inject
    public Messages(final Model model) {
        this.model = model;
        // We only register with the async event bus here because this class
        // is the only one that actually sends events (to itself).
        Events.asyncEventBus().register(this);
    }
    
    @Subscribe
    public void onMessageEvent(final MessageEvent me) {
        if (this.model == null) {
            // Testing?
            LOG.info("Ignoring message with no model...");
            return;
        }
        LOG.info("Adding message...");
        model.addNotification(me.getMsg(), me.getType(), 30);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
    }

    /**
     * Send an info message.
     * 
     * @param key The key for looking up the translated version of the message.
     */
    public void info(final MessageKey key) {
        msg(key, MessageType.info);
    }

    /**
     * Send an info message with replacement variables in the message.
     * 
     * @param key The key for looking up the translated version of the message.
     * @param args The replacement strings to place in the message.
     */
    public void info(final MessageKey key, final String... args) {
        msg(key, MessageType.info, args);
    }
    
    /**
     * Send an info message with replacement variables in the message.
     * 
     * @param key The key for looking up the translated version of the message.
     * @param timeout The time to dislay the message in seconds.
     * @param args The replacement strings to place in the message.
     */
    public void info(final MessageKey key, final int timeout, 
            final String... args) {
        msg(key, MessageType.info, timeout, args);
    }
    
    /**
     * Send an warning message with replacement variables in the message.
     * 
     * @param key The key for looking up the translated version of the message.
     * @param args The replacement strings to place in the message.
     */
    public void warn(final MessageKey key, final String... args) {
        msg(key, MessageType.warning, args);
    }
    
    /**
     * Send an error message with replacement variables in the message.
     * 
     * @param key The key for the translated version of the message.
     * @param args The replacement strings to place in the message.
     */
    public void error(final MessageKey key, final String... args) {
        msg(key, MessageType.error, args);
    }
    
    /**
     * Sends a message of the given type with the given key to lookup a 
     * translated version and with the given replacement arguments to place
     * with the message.
     * 
     * @param key The key for looking up the translated version of the message.
     * @param type The type of the message (info, warning, error, etc).
     * @param args The replacement strings to place in the message.
     */
    public void msg(final MessageKey key, final MessageType type, 
            final String... args) {
        msg(key, type, DEFAULT_DISPLAY_TIME, args);
    }
    
    /**
     * Sends a message of the given type with the given key to lookup a 
     * translated version and with the given replacement arguments to place
     * with the message.
     * 
     * @param key The key for looking up the translated version of the message.
     * @param type The type of the message (info, warning, error, etc).
     * @param timeout The time to dislay the message in seconds.
     * @param args The replacement strings to place in the message.
     */
    public void msg(final MessageKey key, final MessageType type, 
            final int timeout, final String... args) {
        // Our translation files use a slightly different form of replacement,
        // so normalize them.
        final String msg = tr(key);
        final String formatted = String.format(msg, args);
        msg(formatted, type, timeout);
    }

    private void msg(final String msg, final MessageType type) {
        msg(msg, type, DEFAULT_DISPLAY_TIME);
    }
    
    private void msg(final String msg, final MessageType type, 
            final int timeout) {
        model.addNotification(msg, type, timeout);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
    }

    /**
     * Warn-level message.
     * 
     * @param key The key for looking up the translated version of the message.
     */
    public void warn(final MessageKey key) {
        msg(key, MessageType.warning);
    }
    
    /**
     * Display an error-level message.
     * 
     * @param key The key for the translated version of the message.
     * @param t The Throwable.
     */
    public void error(final MessageKey key, final Throwable t) {
        LOG.error(key.toString(), t);
        msg(key, MessageType.error);
    }
    
    /**
     * Display an error-level message.
     * 
     * @param key The key for the translated version of the message.
     * @param t The Throwable.
     * @param args The replacement strings to place in the message.
     */
    public void error(final MessageKey key, final Throwable t, 
            final String... args) {
        LOG.error(key.toString(), t);
        msg(key, MessageType.error, args);
    }
    
    /**
     * Sends a message of the given type with the given key to lookup a 
     * translated version and with the given replacement arguments to place
     * with the message.
     * 
     * @param key The key for looking up the translated version of the message.
     * @param type The type of the message (info, warning, error, etc).
     */
    public void msg(final MessageKey key, final MessageType type) {
        LOG.info("Messaging!!");
        final String msg = tr(key);
        msg(msg, type);
    }
}
