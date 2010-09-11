package org.mg.client;

import java.lang.management.ManagementFactory;
import java.net.SocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.ClosedChannelException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Collection;
import java.util.HashSet;

import javax.management.InstanceAlreadyExistsException;
import javax.management.MBeanRegistrationException;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.NotCompliantMBeanException;
import javax.management.ObjectName;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.util.CharsetUtil;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.mg.common.MessageWriter;
import org.mg.common.OutOfSequenceMessageProcessor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all HTTP requests from the browser to the proxy.
 */
public class HttpRequestHandler extends SimpleChannelUpstreamHandler 
    implements MessageListener, HttpRequestHandlerData {

    private final static Logger log = 
        LoggerFactory.getLogger(HttpRequestHandler.class);
    private static final String HTTP_KEY = "HTTP";
    
    private static int totalBrowserToProxyConnectionsAllClasses = 0;
    
    private int totalBrowserToProxyConnections = 0;
    private int browserToProxyConnections = 0;
    
    private volatile int messagesReceived = 0;
    
    private final ChannelGroup channelGroup;

    private final Chat chat;
    
    private long outgoingSequenceNumber = 0L;
    private Channel browserToProxyChannel;
    
    private MessageListener sequencer;

    private final String macAddress;
    
    private long bytesSent = 0L;
    
    /**
     * Unique key identifying this connection.
     */
    private final String key;
    
    private final Collection<SocketAddress> incomingIps = 
        new HashSet<SocketAddress>();
    
    /**
     * Creates a new class for handling HTTP requests with the specified
     * authentication manager.
     * 
     * @param channelGroup The group of channels for keeping track of all
     * channels we've opened.
     * @param clientChannelFactory The common channel factory for clients.
     * @param conn The XMPP connection. 
     * @param macAddress The unique MAC address for this host.
     */
    public HttpRequestHandler(final ChannelGroup channelGroup, 
        final String macAddress, final Chat chat) {
        this.channelGroup = channelGroup;
        this.macAddress = macAddress;
        this.chat = chat;
        this.key = newKey(this.macAddress, this.hashCode());
        configureJmx();
    }
    
    private void configureJmx() {
        final MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
        try {
            final Class<? extends HttpRequestHandler> clazz = getClass();
            final String pack = clazz.getPackage().getName();
            final String oName =
                pack+":type="+clazz.getSimpleName()+"-"+clazz.getSimpleName()+
                "-"+this.key;
            final ObjectName mxBeanName = new ObjectName(oName);
            if(!mbs.isRegistered(mxBeanName)) {
                log.info("Registering MBean with name: {}", oName);
                mbs.registerMBean(this, mxBeanName);
            }
        } catch (final MalformedObjectNameException e) {
            log.error("Could not set up JMX", e);
        } catch (final InstanceAlreadyExistsException e) {
            log.error("Could not set up JMX", e);
        } catch (final MBeanRegistrationException e) {
            log.error("Could not set up JMX", e);
        } catch (final NotCompliantMBeanException e) {
            log.error("Could not set up JMX", e);
        }

    }

    private String newKey(String mac, int hc) {
        return mac.trim() + hc;
    }
    
    private String toMd5(final byte[] raw) {
        try {
            final MessageDigest md = MessageDigest.getInstance("MD5");
            final byte[] digest = md.digest(raw);
            return Base64.encodeBase64URLSafeString(digest);
        } catch (final NoSuchAlgorithmException e) {
            log.error("No MD5 -- will never happen", e);
            return "NO MD5";
        }
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received "+messagesReceived+" total messages");
        //final HttpRequest request = (HttpRequest) me.getMessage();
        //final long contentLength = HttpHeaders.getContentLength(request);
        
        //log.info("Content-Length: "+contentLength);
        
        final Channel ch = ctx.getChannel();
        try {
            final ChannelBuffer cb = (ChannelBuffer) me.getMessage();
            final ByteBuffer buf = cb.toByteBuffer();
            final byte[] raw = toRawBytes(buf);
            final String base64 = Base64.encodeBase64URLSafeString(raw);
            final Message msg = newMessage(ch);
            msg.setProperty(HTTP_KEY, base64);
            this.chat.sendMessage(msg);
            outgoingSequenceNumber++;
            log.info("Sent XMPP message!!");
        } catch (final XMPPException e) {
            log.error("Error sending message", e);
        }
    }

    private Message newMessage(final Channel ch) {
        final Message msg = new Message();
        // The other side will also need to know where the request came
        // from to differentiate incoming HTTP connections.
        msg.setProperty("LOCAL-IP", ch.getLocalAddress().toString());
        msg.setProperty("REMOTE-IP", ch.getRemoteAddress().toString());
        msg.setProperty("MAC", this.macAddress);
        msg.setProperty("HASHCODE", String.valueOf(this.hashCode()));
        
        // We set the sequence number in case the XMPP server delivers the 
        // packets out of order for any reason.
        msg.setProperty("SEQ", outgoingSequenceNumber);
        return msg;
    }

    
    public static byte[] toRawBytes(final ByteBuffer buf) {
        final int mark = buf.position();
        final byte[] bytes = new byte[buf.remaining()];
        buf.get(bytes);
        buf.position(mark);
        return bytes;
    }
    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) throws Exception {
        final Channel inboundChannel = cse.getChannel();
        log.info("New channel opened: {}", inboundChannel);
        totalBrowserToProxyConnectionsAllClasses++;
        browserToProxyConnections++;
        totalBrowserToProxyConnections++;
        log.info("Now "+totalBrowserToProxyConnectionsAllClasses+" browser to proxy channels...");
        log.info("Now this class has "+browserToProxyConnections+" browser to proxy channels...");
        
        if (this.browserToProxyChannel != null) {
            log.error("Got a second channel opened??!");
        }
        this.sequencer = new OutOfSequenceMessageProcessor(inboundChannel, 
            this.key, new MessageWriter() {
                public void write(final Message msg) {
                    writeData(msg);
                }
            });
        this.browserToProxyChannel = inboundChannel;
        
        // We need to keep track of the channel so we can close it at the end.
        this.channelGroup.add(inboundChannel);
        
        this.incomingIps.add(inboundChannel.getRemoteAddress());
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) {
        final Channel ch = cse.getChannel();
        log.info("Channel closed: {}", ch);
        totalBrowserToProxyConnectionsAllClasses--;
        browserToProxyConnections--;
        log.info("Now "+totalBrowserToProxyConnectionsAllClasses+
            " total browser to proxy channels...");
        log.info("Now this class has "+browserToProxyConnections+
            " browser to proxy channels...");
        
        // The following should always be the case with
        // @ChannelPipelineCoverage("one")
        // We need to notify the remote server that the client connection 
        // has closed.
        if (browserToProxyConnections == 0) {
            log.warn("Closing all proxy to web channels for this browser " +
                "to proxy connection!!!");
            
            final Message msg = newMessage(ch);
            
            msg.setProperty("CLOSE", "true");
            
            try {
                this.chat.sendMessage(msg);
                log.info("Sent close message");
            } catch (final XMPPException e) {
                log.warn("Error sending close message!!", e);
            }
        }
        this.incomingIps.remove(ch.getRemoteAddress());
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        final Channel channel = e.getChannel();
        final Throwable cause = e.getCause();
        if (cause instanceof ClosedChannelException) {
            log.info("Caught an exception on browser to proxy channel: "+
                channel, cause);
        }
        else {
            log.warn("Caught an exception on browser to proxy channel: "+
                channel, cause);
        }
        if (channel.isOpen()) {
            closeOnFlush(channel);
        }
    }
    
    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    private static void closeOnFlush(final Channel ch) {
        log.info("Closing on flush: {}", ch);
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
    }
    
    public void processMessage(final Chat ch, final Message msg) {
        // We just pass the message on to the sequencer that takes care of
        // re-ordering messages that come in out of order.
        this.sequencer.processMessage(ch, msg);
    }

    private void writeData(final Message msg) {
        final String data = (String) msg.getProperty(HTTP_KEY);
        final byte[] raw = 
            Base64.decodeBase64(data.getBytes(CharsetUtil.UTF_8));
        
        final String md5 = toMd5(raw);
        final String expected = (String) msg.getProperty("MD5");
        if (!md5.equals(expected)) {
            log.error("MD-5s not equal!! Expected:\n'"+expected+
                "'\nBut was:\n'"+md5+"'");
        }
        else {
            log.info("MD-5s match!!");
        }
        
        //log.info("Wrapping data: {}", new String(raw, CharsetUtil.UTF_8));
        bytesSent += raw.length;
        log.info("Now sent "+bytesSent+" bytes after "+raw.length+" new");
        final ChannelBuffer cb = ChannelBuffers.wrappedBuffer(raw);
        
        if (browserToProxyChannel.isOpen()) {
            browserToProxyChannel.write(cb);
        }
        else {
            log.info("Not sending data to closed browser connection");
        }
    }

    public int getTotalBrowserToProxyConnections() {
        return totalBrowserToProxyConnections;
    }
    
    public int getTotalBrowserToProxyConnectionsAllClasses() {
        return totalBrowserToProxyConnectionsAllClasses;
    }

    private long startTime = System.currentTimeMillis();
    
    public long getLifetime() {
        return System.currentTimeMillis() - startTime;
    }

    public int getCurrentBrowserToProxyConnections() {
        return browserToProxyConnections;
    }

    public String getIncomingIps() {
        synchronized (this.incomingIps) {
            final StringBuilder sb = new StringBuilder();
            for (final SocketAddress sa : this.incomingIps) {
                sb.append(sa.toString());
                sb.append("\n");
            }
            return sb.toString();
        }
    }

    public int getMessagesReceived() {
        return messagesReceived;
    }
}
