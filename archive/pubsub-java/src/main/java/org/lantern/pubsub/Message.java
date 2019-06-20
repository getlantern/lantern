package org.lantern.pubsub;

/**
 * A Message
 */
public class Message {
    private byte type;
    private byte[] topic;
    private byte[] body;

    public Message(byte type, byte[] topic, byte[] body) {
        super();
        this.type = type;
        this.topic = topic;
        this.body = body;
    }

    public Message() {
    }

    public byte getType() {
        return type;
    }

    public void setType(byte type) {
        this.type = type;
    }

    public byte[] getTopic() {
        return topic;
    }

    public void setTopic(byte[] topic) {
        this.topic = topic;
    }

    public byte[] getBody() {
        return body;
    }

    public void setBody(byte[] body) {
        this.body = body;
    }

}
