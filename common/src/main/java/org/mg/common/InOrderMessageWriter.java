package org.mg.common;

import org.jivesoftware.smack.packet.Message;

/**
 * Interface for classes that write ordered messages to a consumer that cares
 * they're in the correct order, such as a web browser or a web site.
 */
public interface InOrderMessageWriter {

    /**
     * Notification to write the specified message. Called in-order as always.
     * 
     * @param msg The message to write.
     */
    void write(Message msg);

    /**
     * Called when we get a message to close the connection. This is only
     * called when the close is requested in proper sequence. Otherwise,
     * the caller will wait for the proper messages before making this call.
     */
    void onClose();

}
