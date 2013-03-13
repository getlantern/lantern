package org.lantern.state;

public class Notification {
    private String type;
    private String message;

    private int autoClose = 0;

    Notification() {
    }

    Notification(String message, String type) {
        this.message = message;
        this.type = type;
    }

    public String getMessage() {
        return message;
    }
    public void setMessage(String message) {
        this.message = message;
    }
    public String getType() {
        return type;
    }
    public void setType(String type) {
        this.type = type;
    }

    public int getAutoClose() {
        return autoClose;
    }

    public void setAutoClose(int autoClose) {
        this.autoClose = autoClose;
    }

}
