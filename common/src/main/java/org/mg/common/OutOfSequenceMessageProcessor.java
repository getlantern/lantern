package org.mg.common;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.packet.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class OutOfSequenceMessageProcessor implements MessageListener {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private long expectedSequenceNumber = 0L;
    
    private final Map<Long, Message> sequenceMap = 
        new ConcurrentHashMap<Long, Message>();

    private final Channel browserToProxyChannel;

    private final String key;

    private final MessageWriter messageWriter;
    
    public OutOfSequenceMessageProcessor(final Channel browserToProxyChannel, 
        final String key, final MessageWriter messageWriter) {
        this.browserToProxyChannel = browserToProxyChannel;
        this.key = key;
        this.messageWriter = messageWriter;
    }
    
    public void processMessage(final Chat ch, final Message msg) {
        log.info("Received message with props: {}", 
            msg.getPropertyNames());
        final long sequenceNumber = (Long) msg.getProperty("SEQ");
        log.info("SEQUENCE NUMBER: "+sequenceNumber+ " FOR: "+hashCode() + 
            " BROWSER TO PROXY CHANNEL: "+browserToProxyChannel);

        // If the other side is sending the close directive, we 
        // need to close the connection to the browser.
        if (isClose(msg)) {
            // This will happen quite often, as the XMPP server won't 
            // necessarily deliver messages in order.
            if (sequenceNumber != expectedSequenceNumber) {
                log.info("BAD SEQUENCE NUMBER ON CLOSE. " +
                    "EXPECTED "+expectedSequenceNumber+
                    " BUT WAS "+sequenceNumber);
                sequenceMap.put(sequenceNumber, msg);
            }
            else {
                log.info("Got CLOSE. Closing channel to browser: {}", 
                    browserToProxyChannel);
                if (browserToProxyChannel.isOpen()) {
                    log.info("Remaining messages: "+this.sequenceMap);
                    closeOnFlush(browserToProxyChannel);
                }
            }
            return;
        }
        
        // We need to grab the HTTP data from the message and send
        // it to the browser.
        final String data = (String) msg.getProperty("HTTP");
        if (data == null) {
            log.warn("No HTTP data");
            return;
        }
        
        final String mac = (String) msg.getProperty("MAC");
        final String hc = (String) msg.getProperty("HASHCODE");
        final String localKey = newKey(mac, Integer.parseInt(hc));
        if (!localKey.equals(this.key)) {
            log.error("RECEIVED A MESSAGE THAT'S NOT FOR US?!?!?!");
            log.error("\nOUR KEY IS:   "+this.key+
                      "\nBUT RECEIVED: "+localKey);
        }
    
        synchronized (this) {
            if (sequenceNumber != expectedSequenceNumber) {
                log.info("BAD SEQUENCE NUMBER. " +
                    "EXPECTED "+expectedSequenceNumber+
                    " BUT WAS "+sequenceNumber+" FOR KEY: "+localKey);
                sequenceMap.put(sequenceNumber, msg);
            }
            else {
                this.messageWriter.write(msg);
                expectedSequenceNumber++;
                
                while (sequenceMap.containsKey(expectedSequenceNumber)) {
                    log.info("WRITING SEQUENCE number: "+
                        expectedSequenceNumber);
                    final Message curMessage = 
                        sequenceMap.remove(expectedSequenceNumber);
                    
                    // It's possible to get the close event itself out of
                    // order, so we need to check if the stored message is a
                    // close message.
                    if (isClose(curMessage)) {
                        log.info("Detected out-of-order CLOSE message!");
                        closeOnFlush(browserToProxyChannel);
                        break;
                    }
                    this.messageWriter.write(msg);
                    //writeData(curMessage);
                    expectedSequenceNumber++;
                }
            }
        }
    }
    
    private String newKey(final String mac, final int hc) {
        return mac.trim() + hc;
    }
    
    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    private void closeOnFlush(final Channel ch) {
        log.info("Closing on flush: {}", ch);
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
    }
    
    private boolean isClose(final Message msg) {
        final String close = (String) msg.getProperty("CLOSE");
        log.info("Close is: {}", close);

        // If the other side is sending the close directive, we 
        // need to close the connection to the browser.
        return 
            StringUtils.isNotBlank(close) && 
            close.trim().equalsIgnoreCase("true");
    }

}
