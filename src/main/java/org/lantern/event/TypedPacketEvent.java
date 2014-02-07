package org.lantern.event;

import org.jivesoftware.smack.packet.Presence.Type;

public class TypedPacketEvent {

    private final String recipient;
    private final Type type;

    public TypedPacketEvent(final String recipient, final Type type) {
        this.recipient = recipient;
        this.type = type;
    }

    public String getRecipient() {
        return recipient;
    }

    public Type getType() {
        return type;
    }
}
