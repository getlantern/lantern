package org.lantern.state;

import org.lantern.annotation.Keep;

@Keep
public class Notification {
    private MessageType type;
    private String message;
    private boolean background;

    @Keep
    public enum MessageType {
        info, warning, error, success, important;
    }

    /**
     * Timeout in seconds for when the front-end should autoclose the message. 0
     * means no autoclose.
     */
    private int autoClose = 0;

    Notification() {
    }

    Notification(String message, MessageType type) {
        this(message, type, 0);
    }

    public Notification(String message, MessageType type, int timeout) {
        this(type, message, timeout, false);
    }
    
    public Notification(MessageType type, String message,
            int autoClose, boolean background) {
        super();
        this.type = type;
        this.message = message;
        this.autoClose = autoClose;
        this.background = background;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public MessageType getType() {
        return type;
    }

    public void setType(MessageType type) {
        this.type = type;
    }

    public int getAutoClose() {
        return autoClose;
    }

    public void setAutoClose(int autoClose) {
        this.autoClose = autoClose;
    }
    
    public boolean isBackground() {
        return background;
    }
    
    public void setBackground(boolean background) {
        this.background = background;
    }

    @Override
    public String toString() {
        return "Notification [type=" + type + ", message=" + message
                + ", autoClose=" + autoClose + "]";
    }

}
