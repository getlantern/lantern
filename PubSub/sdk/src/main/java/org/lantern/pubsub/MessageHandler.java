package org.lantern.pubsub;

/**
 * Callback for handling received {@link Message}s.
 */
public interface MessageHandler {
    void onMessage(Message message);
}
