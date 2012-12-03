package org.lantern.events;

public class MessageEvent {

    private final String title;
    private final String msg;

    public MessageEvent(final String title, final String msg) {
        this.title = title;
        this.msg = msg;
    }

    public String getTitle() {
        return title;
    }

    public String getMsg() {
        return msg;
    }

}
