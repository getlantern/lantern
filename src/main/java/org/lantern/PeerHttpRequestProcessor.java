package org.lantern;

import static org.jboss.netty.buffer.ChannelBuffers.copiedBuffer;
import static org.jboss.netty.buffer.ChannelBuffers.wrappedBuffer;

import java.io.IOException;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.util.Map;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpChunkTrailer;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.util.CharsetUtil;
import org.littleshoot.util.ByteBufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor that sends requests to peers.
 */
public class PeerHttpRequestProcessor implements HttpRequestProcessor {

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

    private boolean chunked;

    private volatile boolean startedCopying;

    private final Socket sock;

    private final LanternSocketsUtil socketsUtil;

    public PeerHttpRequestProcessor(final Socket sock,
        final LanternSocketsUtil socketsUtil) {
        this.sock = sock;
        this.socketsUtil = socketsUtil;
    }

    @Override
    public boolean processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) 
        throws IOException {
        if (!startedCopying) {
            // We tell the socket not to record stats here because traffic
            // returning to the browser still goes through our encoder 
            // here (i.e. we haven't stripped the encoder to support 
            // CONNECT traffic).
            socketsUtil.startReading(this.sock, browserToProxyChannel, false);
            startedCopying = true;
        }

        final HttpRequest request = (HttpRequest) me.getMessage();
        this.chunked = LanternUtils.isTransferEncodingChunked(request);
        
        final byte[] data;
        try {
            data = LanternUtils.toByteBuffer(request, ctx);
        } catch (final Exception e) {
            log.error("Could not encode request?", e);
            return true;
        }
        try {
            log.debug("Writing {}", new String(data, "UTF-8"));
            final OutputStream os = this.sock.getOutputStream();
            os.write(data);
            return true;
        } catch (final IOException e) {
            // They probably just closed the connection, as they will in
            // many cases.
            
            // Note that we don't record this "failure," as it's frequently
            // not a failure. We instead actually remove peers from our
            // peer proxy list if we can't connect to them in addition to
            // removing them when we detect they're unavailable through XMPP.
        }
        
        // We return true in all these case to preserve the behavior before
        // the change to return a boolean. The point of returning a boolean
        // was more to consolidate the check for the existence of a proxy with
        // the request processing.
        return true;
    }

    @Override
    public boolean processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        // We need to convert the Netty message to raw bytes for sending over
        // the socket.
        final HttpChunk chunk = (HttpChunk) me.getMessage();
        final ChannelBuffer cb = encodeChunk(chunk);
        if (cb == null) {
            return true;
        }
        
        final ByteBuffer buf = cb.toByteBuffer();
        final byte[] data = ByteBufferUtils.toRawBytes(buf);
        log.debug("Writing chunk {}", new String(data));
        final OutputStream os = this.sock.getOutputStream();
        os.write(data);
        return true;
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
    
    private void encodeTrailingHeaders(final ChannelBuffer buf, 
        final HttpChunkTrailer trailer) {
        try {
            for (final Map.Entry<String, String> h: trailer.getHeaders()) {
                encodeHeader(buf, h.getKey(), h.getValue());
            }
        } catch (final UnsupportedEncodingException e) {
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

    @Override
    public void close() {
        IOUtils.closeQuietly(this.sock);
    }
}
