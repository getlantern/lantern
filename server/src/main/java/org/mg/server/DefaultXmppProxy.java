package org.mg.server;

import static org.jboss.netty.channel.Channels.pipeline;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.util.CharsetUtil;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.ChatManagerListener;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.littleshoot.proxy.Launcher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DefaultXmppProxy implements XmppProxy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ClientSocketChannelFactory channelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());
    
    private final ConcurrentHashMap<String, ChannelFuture> connections =
        new ConcurrentHashMap<String, ChannelFuture>();
    
    public DefaultXmppProxy() {
        // Start the HTTP proxy server that we relay data to. It has more
        // developed logic for handling different types of requests, and we'd
        // otherwise have to duplicate that here.
        Launcher.main("7777");
    }
    
    public void start() throws XMPPException, IOException {
        final Properties props = new Properties();
        final File propsDir = new File(System.getProperty("user.home"), ".mg");
        final File propsFile = new File(propsDir, "mg.properties");

        if (!propsFile.isFile()) {
            System.err.println("No properties file found at "+propsFile+
                ". That file is required and must contain a property for " +
                "'user' and 'pass'.");
            System.exit(0);
        }
        props.load(new FileInputStream(propsFile));
        final String user = props.getProperty("google.server.user");
        final String pass = props.getProperty("google.server.pwd");
        
        for (int i = 0; i < 10; i++) {
            // We create a bunch of connections to allow us to process as much
            // incoming data as possible.
            final XMPPConnection xmpp = newConnection(user, pass);
            log.info("Created connection to: {}", xmpp);
        }
    }
    
    private XMPPConnection newConnection(final String user, final String pass) {
        for (int i = 0; i < 10; i++) {
            try {
                return newSingleConnection(user, pass);
            } catch (final XMPPException e) {
                log.error("Could not create XMPP connection", e);
            }
        }
        throw new RuntimeException("Could not connect to XMPP server");
    }

    private XMPPConnection newSingleConnection(final String user, 
        final String pass) 
        throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        final XMPPConnection conn = new XMPPConnection(config);
        conn.connect();
        conn.login(user, pass, "MG");
        
        final ChatManager cm = conn.getChatManager();
        final ChatManagerListener listener = new ChatManagerListener() {
            
            public void chatCreated(final Chat chat, 
                final boolean createdLocally) {
                log.info("Created a chat!!");
                final MessageListener ml = new MessageListener() {
                    
                    public void processMessage(final Chat ch, final Message msg) {
                        log.info("Got message!!");
                        log.info("Property names: {}", msg.getPropertyNames());
                        final String data = (String) msg.getProperty("HTTP");
                        if (StringUtils.isBlank(data)) {
                            log.warn("HTTP IS BLANK?? IGNORING...");
                            return;
                        }
                        
                        // TODO: Check the sequence number??
                        final ChannelBuffer cb = xmppToHttpChannelBuffer(msg);
                        log.info("Getting channel future...");
                        final ChannelFuture cf = getChannelFuture(msg, ch);
                        log.info("Got channel: {}", cf);
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
                };
                chat.addMessageListener(ml);
            }
        };
        cm.addChatListener(listener);
        return conn;
    }

    private ChannelBuffer xmppToHttpChannelBuffer(final Message msg) {
        final String data = (String) msg.getProperty("HTTP");
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
     * @param key The key for the remote IP/port pair.
     * @param chat The chat session across Google Talk -- we need this to 
     * send responses back to the original caller.
     * @return The {@link ChannelFuture} that will connect to the local
     * LittleProxy instance.
     */
    private ChannelFuture getChannelFuture(final Message message, 
        final Chat chat) {
        // The other side will also need to know where the 
        // request came from to differentiate incoming HTTP 
        // connections.
        log.info("Getting properties...");
        
        // Not these will fail if the original properties were not set as
        // strings.
        final String remoteIp = 
            (String) message.getProperty("LOCAL-IP");
        final String localIp = 
            (String) message.getProperty("REMOTE-IP");
        final String MAC = 
            (String) message.getProperty("MAC");
        final String HASHCODE = 
            (String) message.getProperty("HASHCODE");
        
        final String key = MAC + HASHCODE;
        
        log.info("Getting channel future...");
        synchronized (connections) {
            if (connections.containsKey(key)) {
                log.info("Using existing connection");
                return connections.get(key);
            }
            // Configure the client.
            final ClientBootstrap cb = new ClientBootstrap(this.channelFactory);
            
            final ChannelPipelineFactory cpf = new ChannelPipelineFactory() {
                public ChannelPipeline getPipeline() throws Exception {
                    // Create a default pipeline implementation.
                    final ChannelPipeline pipeline = pipeline();
                    
                    final class HttpChatRelay extends SimpleChannelUpstreamHandler {
                        @Override
                        public void messageReceived(
                            final ChannelHandlerContext ctx, 
                            final MessageEvent me) throws Exception {
                            log.info("HTTP message received from proxy on " +
                                "relayer: {}", me.getMessage());
                            final Message msg = new Message();
                            final ByteBuffer buf = 
                                ((ChannelBuffer) me.getMessage()).toByteBuffer();
                            final byte[] raw = toRawBytes(buf);
                            final String base64 = Base64.encodeBase64String(raw);
                            
                            //TODO: Set the sequence number??
                            msg.setProperty("HTTP", base64);
                            chat.sendMessage(msg);
                        }
                        @Override
                        public void channelClosed(final ChannelHandlerContext ctx, 
                            final ChannelStateEvent cse) {
                            // We need to send the CLOSE directive to the other
                            // side VIA google talk to simulate the proxy 
                            // closing the connection to the browser.
                            log.info("Got channel closed on C in A->B->C->D chain...");
                            final Message msg = new Message();
                            msg.setProperty("CLOSE", "true");
                            try {
                                chat.sendMessage(msg);
                            } catch (final XMPPException e) {
                                log.warn("Error sending close message", e);
                            }
                            connections.remove(key);
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
            connections.put(key, future);
            return future;
        }
    }

    public static byte[] toRawBytes(final ByteBuffer buf) {
        final int mark = buf.position();
        final byte[] bytes = new byte[buf.remaining()];
        buf.get(bytes);
        buf.position(mark);
        return bytes;
    }
    
    /*
    private void readRequest(final FileTransferRequest request) 
        throws XMPPException, IOException {
        final IncomingFileTransfer itf = request.accept();
        final long fileSize = request.getFileSize();
        final InputStream in = itf.recieveFile();
        final byte[] b = new byte[BUFFER_SIZE];
        int count = 0;
        int amountWritten = 0;

        // We actually write to a file here because it could be a large POST
        // request.
        final File tempFile = 
            File.createTempFile(String.valueOf(request.hashCode()), null);
        final OutputStream out = new FileOutputStream(tempFile);
        do {
            // write to the output stream
            try {
                out.write(b, 0, count);
            } catch (IOException e) {
                throw new XMPPException("error writing to output stream", e);
            }

            amountWritten += count;

            // read more bytes from the input stream
            try {
                count = in.read(b);
            } catch (IOException e) {
                throw new XMPPException("error reading from input stream", e);
            }
        } while (count != -1 && !itf.getStatus().equals(Status.cancelled));

        // the connection was likely terminated abrubtly if these are not equal
        if (!itf.getStatus().equals(Status.cancelled) && 
             itf.getError() == Error.none && amountWritten != fileSize) {
            itf.setStatus(Status.error);
            itf.setError(Error.connection);
        }
        System.out.println("Read: "+IOUtils.toString(new FileInputStream(tempFile)));
    }
    */
}
