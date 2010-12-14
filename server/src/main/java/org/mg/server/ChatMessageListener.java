package org.mg.server;

import static org.jboss.netty.channel.Channels.pipeline;

import java.lang.management.ManagementFactory;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Map;
import java.util.PriorityQueue;
import java.util.Queue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

import javax.management.InstanceAlreadyExistsException;
import javax.management.MBeanRegistrationException;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.NotCompliantMBeanException;
import javax.management.ObjectName;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.util.CharsetUtil;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.XMPPError;
import org.jivesoftware.smackx.ChatState;
import org.jivesoftware.smackx.ChatStateListener;
import org.lastbamboo.common.amazon.ec2.AmazonEc2Utils;
import org.lastbamboo.common.download.RateCalculator;
import org.lastbamboo.common.download.RateCalculatorImpl;
import org.mg.common.ChatData;
import org.mg.common.XmppMessageConstants;
import org.mg.common.MgUtils;
import org.mg.common.Pair;
import org.mg.common.RangeDownloaderAdaptor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for listening for messages for a specific chat.
 */
public class ChatMessageListener implements ChatStateListener,
    ChatData {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Collection<String> removedConnections = 
        new HashSet<String>();
    
    private final Map<String, ChannelFuture> proxyConnections;

    private final String MAC_ADDRESS;

    private final ChannelFactory channelFactory;
    
    private final ConcurrentHashMap<String, AtomicLong> channelsToSequenceNumbers =
        new ConcurrentHashMap<String, AtomicLong>();

    private final XMPPConnection conn;

    private final Chat chat;
    
    private final RateCalculator rateCalculator = new RateCalculatorImpl();
    
    private Queue<Message> rejected = new PriorityQueue<Message>(100, 
        new Comparator<Message>() {
        public int compare(final Message msg1, final Message msg2) {
            final Long seq1 = (Long) msg1.getProperty(XmppMessageConstants.SEQ);
            final Long seq2 = (Long) msg2.getProperty(XmppMessageConstants.SEQ);
            return seq1.compareTo(seq2);
        }
    });
    

    //private final Queue<Pair<Chat, XMPPConnection>> chatsAndConnections;
    
    //private final Map<Long, Message> rejectedMessages = 
    //    new TreeMap<Long, Message>();

    private volatile long lastResourceConstraintMessage = 0L;
    
    private volatile long totalHttpBytesSent = 0L;
    
    private volatile int totalMessages = 0;
    
    public ChatMessageListener(
        final Map<String, ChannelFuture> proxyConnections, 
        final Queue<Pair<Chat, XMPPConnection>> chatsAndConnections, 
        final String macAddress, final ChannelFactory channelFactory,
        final Chat chat, final XMPPConnection conn) {
        this.proxyConnections = proxyConnections;
        //this.chatsAndConnections = chatsAndConnections;
        this.MAC_ADDRESS = macAddress;
        this.channelFactory = channelFactory;
        this.chat = chat;
        this.conn = conn;
        addJmx();
    }
    
    private void addJmx() {
        final MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
        try {
            final Class<? extends ChatMessageListener> clazz = getClass();
            final String pack = clazz.getPackage().getName();
            final String oName = pack+":type=XmppChat-"+hashCode();
            final ObjectName mxBeanName = new ObjectName(oName);
            if(!mbs.isRegistered(mxBeanName)) {
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

    public void processMessage(final Chat ch, final Message msg) {
        log.info("Got message!!");
        log.info("Property names: {}", msg.getPropertyNames());
        final Integer type = (Integer) msg.getProperty(XmppMessageConstants.TYPE);
        if (type != null) {
            switch (type) {
                case XmppMessageConstants.INFO_REQUEST_TYPE:
                    log.info("Sending info response");
                    sendInfoResponse(ch);
                    break;
                default:
                    log.error("Unhandled type? "+type);
            }
            return;
        }
        else {
            log.info("Type is null");
        }
        
        final long seq = (Long) msg.getProperty(XmppMessageConstants.SEQ);
        log.info("SEQUENCE #: {}", seq);
        log.info("HASHCODE #: {}", 
            msg.getProperty(XmppMessageConstants.HASHCODE));
        
        log.info("FROM: {}",msg.getFrom());
        log.info("TO: {}",msg.getTo());
        final String smac = 
            (String) msg.getProperty(XmppMessageConstants.SERVER_MAC);
        log.info("SMAC: {}", smac);

        if (StringUtils.isNotBlank(smac) && 
            smac.trim().equals(MAC_ADDRESS)) {
            log.error("MESSAGE FROM OURSELVES!! AN ERROR?");
            final XMPPError error = msg.getError();
            if (error != null) {
                final int code = msg.getError().getCode();
                if (code == 500) {
                    // Something's up on the server -- we're probably sending
                    // bytes too fast. Slow down.
                    lastResourceConstraintMessage = System.currentTimeMillis();
                    //rejectedMessages.put(seq, msg);
                    rejected.add(msg);
                }
            }
            MgUtils.printMessage(msg);
            return;
        }
        
        final String closeString = 
            (String) msg.getProperty(XmppMessageConstants.CLOSE);
        
        log.info("Close value: {}", closeString);
        final boolean close;
        if (StringUtils.isNotBlank(closeString) &&
            closeString.trim().equalsIgnoreCase("true")) {
            log.info("Got close true");
            close = true;
        }
        else {
            close = false;
            final String data = 
                (String) msg.getProperty(XmppMessageConstants.HTTP);
            if (StringUtils.isBlank(data)) {
                log.warn("HTTP IS BLANK?? IGNORING...");
                return;
            }
        }

        final String key = messageKey(msg);
        
        if (close) {
            log.info("Received close from client...closing " +
                "connection to the proxy for HASHCODE: {}", 
                msg.getProperty(XmppMessageConstants.HASHCODE));
            final ChannelFuture cf = proxyConnections.get(key);
            
            if (cf != null) {
                log.info("Closing connection");
                cf.getChannel().close();
                removedConnections.add(key);
                proxyConnections.remove(key);
            }
            else {
                log.error("Got close for connection we don't " +
                    "know about! Removed keys are: {}", 
                    removedConnections);
            }
            return;
        }
        log.info("Getting channel future...");
        final ChannelFuture cf = getChannelFuture(msg, close, ch);
        log.info("Got channel: {}", cf);
        if (cf == null) {
            log.info("Null channel future! Returning");
            return;
        }
        
        final ChannelBuffer cb = unwrap(msg);

        final AtomicLong expected = getExpectedSequenceNumber(key);
        if (seq != expected.get()) {
            log.error("GOT UNEXPECTED REQUEST SEQUENCE NUMBER. EXPECTED " + 
                expected.get()+" BUT WAS "+seq);
        }
        expected.incrementAndGet();
        if (cf.getChannel().isConnected()) {
            cf.getChannel().write(cb);
        }
        else {
            cf.addListener(new ChannelFutureListener() {
                public void operationComplete(
                    final ChannelFuture future) 
                    throws Exception {
                    cf.getChannel().write(cb);
                }
            });
        }
    }

    private void sendInfoResponse(final Chat ch) {
        log.info("Sending info response");
        final Message msg = new Message();
        msg.setProperty(XmppMessageConstants.TYPE, 
            XmppMessageConstants.INFO_RESPONSE_TYPE);
        final InetAddress address = AmazonEc2Utils.getPublicAddress();
        final String proxies = 
            address.getHostAddress() + ":"+ServerConstants.PROXY_PORT;
        msg.setProperty(XmppMessageConstants.PROXIES, proxies);
        try {
            ch.sendMessage(msg);
        } catch (final XMPPException e) {
            log.error("Could not send info message", e);
        }
    }

    private AtomicLong getExpectedSequenceNumber(final String key) {
        final AtomicLong zero = new AtomicLong(0);
        final AtomicLong existing =
            channelsToSequenceNumbers.putIfAbsent(key, zero);
        if (existing != null) {
            return existing;
        }
        return zero;
    }

    public void stateChanged(final Chat monitoredChat, final ChatState state) {
        log.info("Got chat state changed: {}", state);
    }

    private ChannelBuffer unwrap(final Message msg) {
        final String data = (String) msg.getProperty(XmppMessageConstants.HTTP);
        final byte[] raw = 
            Base64.decodeBase64(data.getBytes(CharsetUtil.UTF_8));
        return ChannelBuffers.wrappedBuffer(raw);
    }
    
    /**
     * This gets a channel to connect to the local HTTP proxy on. This is 
     * slightly complex, as we're trying to mimic the state as if this HTTP
     * request is coming in to a "normal" LittleProxy instance instead of
     * having the traffic tunneled through XMPP. So we create a separate 
     * connection to the proxy just as those separate connections were made
     * from the browser to the proxy originally on the remote end.
     * 
     * If there's already an existing connection mimicking the original 
     * connection, we use that.
     * 
     * 
     * @return The {@link ChannelFuture} that will connect to the local
     * LittleProxy instance.
     */
    private ChannelFuture getChannelFuture(final Message message, 
        final boolean close, final Chat requestChat) {
        
        // The other side will also need to know where the 
        // request came from to differentiate incoming HTTP 
        // connections.
        log.info("Getting properties...");
        
        // Note these will fail if the original properties were not set as
        // strings.
        final String key = messageKey(message);
        if (StringUtils.isBlank(key)) {
            log.error("Could not create key");
            return null;
        }
        
        log.info("Getting channel future for key: {}", key);
        synchronized (this.proxyConnections) {
            if (proxyConnections.containsKey(key)) {
                log.info("Using existing connection");
                return proxyConnections.get(key);
            }
            if (close) {
                // We've likely already closed the connection in this case.
                log.warn("Returning null channel on close call");
                return null;
            }
            if (removedConnections.contains(key)) {
                log.warn("KEY IS IN REMOVED CONNECTIONS: "+key);
            }
            // Configure the client.
            final ClientBootstrap cb = new ClientBootstrap(this.channelFactory);
            
            final ChannelPipelineFactory cpf = new ChannelPipelineFactory() {
                public ChannelPipeline getPipeline() throws Exception {
                    // Create a default pipeline implementation.
                    final ChannelPipeline pipeline = pipeline();
                    
                    final class HttpChatRelay extends SimpleChannelUpstreamHandler {
                        private AtomicLong sequenceNumber = new AtomicLong(0L);
                        
                        @Override
                        public void messageReceived(
                            final ChannelHandlerContext ctx, 
                            final MessageEvent me) {
                            log.info("HTTP message received from proxy relay");
                            final ByteBuffer buf = 
                                ((ChannelBuffer) me.getMessage()).toByteBuffer();
                            final byte[] raw = MgUtils.toRawBytes(buf);
                            final String base64 = 
                                Base64.encodeBase64URLSafeString(raw);

                            final Message msg = new Message();
                            msg.setProperty(XmppMessageConstants.HTTP, base64);
                            msg.setProperty(XmppMessageConstants.MD5, toMd5(raw));
                            sendMessage(msg, false);
                        }

                        @Override
                        public void channelClosed(final ChannelHandlerContext ctx, 
                            final ChannelStateEvent cse) {
                            // We need to send the CLOSE directive to the other
                            // side VIA google talk to simulate the proxy 
                            // closing the connection to the browser.
                            log.info("Got channel closed on C in A->B->C->D chain...");
                            log.info("Sending close message");
                            final Message msg = new Message();
                            msg.setProperty(XmppMessageConstants.CLOSE, "true");
                            sendMessage(msg, true);
                            
                            removedConnections.add(key);
                            proxyConnections.remove(key);
                        }
                        
                        private void sendMessage(final Message msg, 
                            final boolean isClose) {
                            
                            // We set the sequence number so the client knows
                            // how many total messages to expect. This is 
                            // necessary because the XMPP server can deliver 
                            // messages out of order.
                            msg.setProperty(XmppMessageConstants.SEQ, 
                                sequenceNumber.incrementAndGet() - 1);
                            msg.setProperty(XmppMessageConstants.HASHCODE, 
                                message.getProperty(XmppMessageConstants.HASHCODE));
                            msg.setProperty(XmppMessageConstants.MAC, 
                                message.getProperty(XmppMessageConstants.MAC));
                            
                            // This is the server-side MAC address. This is
                            // useful because there are odd cases where XMPP
                            // servers echo back our own messages, and we
                            // want to ignore them.
                            log.info("Setting SMAC to: {}", MAC_ADDRESS);
                            msg.setProperty(XmppMessageConstants.SERVER_MAC, 
                                MAC_ADDRESS);
                            log.info("Sending SEQUENCE #: "+sequenceNumber);
                            //sentMessages.put(sequenceNumber, msg);
                            
                            log.info("Received from: {}", 
                                requestChat.getParticipant());
                            
                            final long elapsed = 
                                System.currentTimeMillis() - 
                                lastResourceConstraintMessage;
                            if (elapsed < 20000) {
                                if (isClose) {
                                    log.info("Got close...waiting to send");
                                    try {
                                        Thread.sleep(5000);
                                    } catch (InterruptedException e) {
                                    }
                                }
                                else {
                                    log.info("Caching message for sending later...");
                                    rejected.add(msg);
                                    log.info("Now {} cached", rejected.size());
                                    return;
                                }
                            }
                            
                            sendRejects();
                            sendWithChat(msg);
                        }
                        
                        private void sendRejects() {
                            if (!rejected.isEmpty()) {
                                log.info("Sending rejects: {}",rejected.size());
                            }
                            long start = lastResourceConstraintMessage;
                            int newRejects = 0;
                            while (!rejected.isEmpty()) {
                                final Message reject = rejected.poll();
                                sendWithChat(makeCopy(reject));
                                log.info("Waiting before sending message");
                                final long sleepTime;
                                if (lastResourceConstraintMessage != start) {
                                    start = lastResourceConstraintMessage;
                                    newRejects++;
                                    sleepTime = 3000 * newRejects;
                                    log.info("Set sleep time to {}", sleepTime);
                                }
                                else {
                                    sleepTime = 1200;
                                }
                                try {
                                    Thread.sleep(sleepTime);
                                } catch (final InterruptedException e) {
                                    log.error("Error while sleeping?");
                                }
                            }
                        }
                        
                        private void sendWithChat(final Message msg) {
                            log.info("Sending to: {}", chat.getParticipant());
                            msg.setTo(chat.getParticipant());
                            
                            //final XMPPConnection conn = pair.getSecond();
                            final String from = conn.getUser();
                            msg.setFrom(from);
                            
                            final long now = System.currentTimeMillis();
                            try {
                                chat.sendMessage(msg);
                                final String http = (String) msg.getProperty(
                                    XmppMessageConstants.HTTP);
                                final long length;
                                if (StringUtils.isBlank(http)) {
                                    length = 0;
                                }
                                else {
                                    length = http.length();
                                }
                                totalMessages++;
                                totalHttpBytesSent += length;
                                
                                rateCalculator.addData(new RangeDownloaderAdaptor() {
                                    
                                    @Override
                                    public long getRangeStartTime() {
                                        return now;
                                    }
                                    
                                    @Override
                                    public long getRangeIndex() {
                                        return (Long) msg.getProperty(XmppMessageConstants.SEQ);
                                    }
                                    
                                    @Override
                                    public long getNumBytesDownloaded() {
                                        return length;
                                    }
                                    
                                });
                                
                                
                                // Note we don't do this in a finally block.
                                // if an exception happens, it's likely there's
                                // something wrong with the chat, and we don't
                                // want to add it back.
                                //chatsAndConnections.offer(pair);
                            } catch (final XMPPException e) {
                                log.error("Could not send chat message", e);
                            }
                        }

                        private Message makeCopy(final Message reject) {
                            final Message msg = new Message();
                            msg.setProperty(XmppMessageConstants.SEQ, 
                                reject.getProperty(XmppMessageConstants.SEQ));
                            msg.setProperty(XmppMessageConstants.HASHCODE, 
                                reject.getProperty(XmppMessageConstants.HASHCODE));
                            msg.setProperty(XmppMessageConstants.MAC, 
                                reject.getProperty(XmppMessageConstants.MAC));
                            msg.setProperty(XmppMessageConstants.SERVER_MAC, 
                                MAC_ADDRESS);
                            //msg.setTo(chat.getParticipant());
                            //msg.setFrom(conn.getUser());
                            
                            final String http = 
                                (String) reject.getProperty(XmppMessageConstants.HTTP);
                            if (StringUtils.isNotBlank(http)) {
                                msg.setProperty(XmppMessageConstants.HTTP, http);
                                msg.setProperty(XmppMessageConstants.MD5, 
                                    reject.getProperty(XmppMessageConstants.MD5));
                            }
                            return msg;
                        }

                        @Override
                        public void exceptionCaught(final ChannelHandlerContext ctx, 
                            final ExceptionEvent e) throws Exception {
                            log.error("Caught exception on C in A->B->C->D " +
                                "chain...", e.getCause());
                            if (e.getChannel().isOpen()) {
                                log.warn("Closing open connection");
                                closeOnFlush(e.getChannel());
                            }
                            else {
                                // We've seen odd cases where channels seem to 
                                // continually attempt connections. Make sure 
                                // we explicitly close the connection here.
                                log.info("Channel is not open...ignoring");
                                //log.warn("Closing connection even though " +
                                //    "isOpen is false");
                                //e.getChannel().close();
                            }
                        }
                    }
                    
                    pipeline.addLast("handler", new HttpChatRelay());
                    return pipeline;
                }
            };
                
            // Set up the event pipeline factory.
            cb.setPipelineFactory(cpf);
            cb.setOption("connectTimeoutMillis", 40*1000);

            log.info("Connecting to localhost proxy");
            final ChannelFuture future = 
                cb.connect(new InetSocketAddress("127.0.0.1", 7777));
            proxyConnections.put(key, future);
            return future;
        }
    }
    
    private String messageKey(final Message message) {
        final String mac = 
            (String) message.getProperty(XmppMessageConstants.MAC);
        final String hc = 
            (String) message.getProperty(XmppMessageConstants.HASHCODE);

        // We can sometimes get messages back that were not intended for us.
        // Just ignore them.
        if (mac == null || hc == null) {
            log.error("Message not intended for us?!?!?\n" +
                "Null MAC and/or HASH and to: "+message.getTo());
            return null;
        }
        final String key = mac + hc;
        return key;
    }
    
    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    private void closeOnFlush(final Channel ch) {
        log.info("Closing channel on flush: {}", ch);
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
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

    public double getRate() {
        return rateCalculator.getRate();
    }

    public int getAverageMessageSize() {
        if (totalMessages == 0) {
            return 0;
        }
        return (int) (totalHttpBytesSent/totalMessages);
    }

    public int getTotalMessages() {
        return totalMessages;
    }

    public long getTotalBytes() {
        return totalHttpBytesSent;
    }
}

