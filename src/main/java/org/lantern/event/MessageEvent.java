package org.lantern.event;

import org.lantern.state.Notification.MessageType;

/**
 * Event for showing messages to the user.
 */
public class MessageEvent {

    private final String title;
    private final String msg;
    private final MessageType type;
    
    public MessageEvent(final String title, final String msg) {
        this.title = title;
        this.msg = msg;
        this.type = MessageType.info;
    }

    public MessageEvent(final String title, final String msg, 
            final MessageType type) {
        this.title = title;
        this.msg = msg;
        this.type = type;
    }

    public MessageEvent(final String msg, MessageType type) {
        this.msg = msg;
        this.type = type;
        this.title = "";
    }

    public String getTitle() {
        return title;
    }

    public String getMsg() {
        return msg;
    }

    public MessageType getType() {
        return type;
    }

}
