package org.mg.common;

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jivesoftware.smack.packet.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class MgUtils {

    private static final Logger LOG = LoggerFactory.getLogger(MgUtils.class);
    
    
    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    public static void closeOnFlush(final Channel ch) {
        LOG.info("Closing channel on flush: {}", ch);
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
    }
    
    public static String toMd5(final byte[] raw) {
        try {
            final MessageDigest md = MessageDigest.getInstance("MD5");
            final byte[] digest = md.digest(raw);
            return Base64.encodeBase64URLSafeString(digest);
        } catch (final NoSuchAlgorithmException e) {
            LOG.error("No MD5 -- will never happen", e);
            return "NO MD5";
        }
    }

    public static byte[] toRawBytes(final ByteBuffer buf) {
        final int mark = buf.position();
        final byte[] bytes = new byte[buf.remaining()];
        buf.get(bytes);
        buf.position(mark);
        return bytes;
    }

    public static void printMessage(final Message msg) {
        final StringBuilder sb = new StringBuilder();
        sb.append("MESSAGE:");
        sb.append("\nBODY:");
        sb.append(msg.getBody());
        sb.append("\nFROM:");
        sb.append(msg.getFrom());
        sb.append("\nTO:");
        sb.append(msg.getTo());
        sb.append("\nSUBJECT:");
        sb.append(msg.getSubject());
        sb.append("\nPACKET ID:");
        sb.append(msg.getPacketID());
        sb.append("\nERROR:");
        sb.append(msg.getError());
        sb.append("\nEXTENSIONS:");
        sb.append(msg.getExtensions());
        sb.append("\nTYPE:");
        sb.append(msg.getType());
        sb.append("\nPROPERTY NAMES:");
        sb.append(msg.getPropertyNames());
        LOG.warn(sb.toString());
    }
}
