package org.lantern;

import static org.jboss.netty.buffer.ChannelBuffers.copiedBuffer;
import static org.jboss.netty.buffer.ChannelBuffers.wrappedBuffer;

import java.io.IOException;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.util.Map;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpChunkTrailer;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.util.CharsetUtil;
import org.littleshoot.util.ByteBufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SocketChunkWriter implements OutgoingWriter {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    //space ' '
    static final byte SP = 32;
    
    /**
     * Colon ':'
     */
     static final byte COLON = 58;
    
    /**
     * Carriage return
     */
    static final byte CR = 13;

    /**
     * Equals '='
     */
    static final byte EQUALS = 61;

    /**
     * Line feed character
     */
    static final byte LF = 10;

    /**
     * carriage return line feed
     */
    static final byte[] CRLF = new byte[] { CR, LF };
    
    private static final ChannelBuffer LAST_CHUNK =
        copiedBuffer("0\r\n\r\n", CharsetUtil.US_ASCII);
    
    private final Socket sock;

    private final boolean chunked;

    public SocketChunkWriter(final Socket sock, final HttpRequest request) {
        this.sock = sock;
        this.chunked = LanternUtils.isTransferEncodingChunked(request);
    }

    public void write(final MessageEvent me) throws IOException {
        // We need to convert the Netty message to raw bytes for sending over
        // the socket.
        final HttpChunk chunk = (HttpChunk) me.getMessage();
        final ChannelBuffer cb = encodeChunk(chunk);
        if (cb == null) {
            return;
        }
        
        final ByteBuffer buf = cb.toByteBuffer();
        final byte[] data = ByteBufferUtils.toRawBytes(buf);
        log.info("Writing {}", new String(data));
        final OutputStream os = sock.getOutputStream();
        os.write(data);
    }
    
    private ChannelBuffer encodeChunk(final HttpChunk chunk) {
        if (chunked) {
            if (chunk.isLast()) {
                // We create new chunk writers every time, so we don't need to 
                // reset the chunk flag.
                //chunked = false;
                if (chunk instanceof HttpChunkTrailer) {
                    ChannelBuffer trailer = ChannelBuffers.dynamicBuffer();
                    trailer.writeByte((byte) '0');
                    trailer.writeByte(CR);
                    trailer.writeByte(LF);
                    encodeTrailingHeaders(trailer, (HttpChunkTrailer) chunk);
                    trailer.writeByte(CR);
                    trailer.writeByte(LF);
                    return trailer;
                } else {
                    return LAST_CHUNK.duplicate();
                }
            } else {
                ChannelBuffer content = chunk.getContent();
                int contentLength = content.readableBytes();

                return wrappedBuffer(
                        copiedBuffer(
                                Integer.toHexString(contentLength),
                                CharsetUtil.US_ASCII),
                        wrappedBuffer(CRLF),
                        content.slice(content.readerIndex(), contentLength),
                        wrappedBuffer(CRLF));
            }
        } else {
            if (chunk.isLast()) {
                return null;
            } else {
                return chunk.getContent();
            }
        }
    }
    
    private void encodeTrailingHeaders(ChannelBuffer buf, HttpChunkTrailer trailer) {
        try {
            for (Map.Entry<String, String> h: trailer.getHeaders()) {
                encodeHeader(buf, h.getKey(), h.getValue());
            }
        } catch (UnsupportedEncodingException e) {
            throw (Error) new Error().initCause(e);
        }
    }

    private void encodeHeader(ChannelBuffer buf, String header, String value)
            throws UnsupportedEncodingException {
        buf.writeBytes(header.getBytes("ASCII"));
        buf.writeByte(COLON);
        buf.writeByte(SP);
        buf.writeBytes(value.getBytes("ASCII"));
        buf.writeByte(CR);
        buf.writeByte(LF);
    }

}
