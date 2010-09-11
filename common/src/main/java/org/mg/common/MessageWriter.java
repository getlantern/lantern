package org.mg.common;

import org.jivesoftware.smack.packet.Message;

public interface MessageWriter {

    void write(Message msg);

}
