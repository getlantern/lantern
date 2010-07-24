package org.mg.client;


import static org.jboss.netty.channel.Channels.pipeline;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Properties;
import java.util.concurrent.Executors;

import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.jboss.netty.handler.codec.http.HttpResponseEncoder;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Presence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.xml.internal.bind.v2.model.annotation.RuntimeInlineAnnotationReader;

/**
 * Factory for creating pipelines for incoming requests to our listening
 * socket.
 */
public class HttpServerPipelineFactory implements ChannelPipelineFactory {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ChannelGroup channelGroup;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());

    private final String user;

    private final String pwd;

    private XMPPConnection conn;

    /**
     * Creates a new pipeline factory with the specified class for processing
     * proxy authentication.
     * 
     * @param authorizationManager The manager for proxy authentication.
     * @param channelGroup The group that keeps track of open channels.
     * @param filters HTTP filters to apply.
     */
    public HttpServerPipelineFactory(final ChannelGroup channelGroup) {
        this.channelGroup = channelGroup;
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            public void run() {
                clientSocketChannelFactory.releaseExternalResources();
            }
        }));
        final Properties props = new Properties();
        final File propsDir = new File(System.getProperty("user.home"), ".mg");
        final File file = new File(propsDir, "mg.properties");
        try {
            props.load(new FileInputStream(file));
            this.user = props.getProperty("google.user");
            this.pwd = props.getProperty("google.pwd");
            newXmppConnection();
        } catch (final IOException e) {
            final String msg = "Error loading props file at: " + file;
            log.error(msg);
            throw new RuntimeException(msg, e);
        } catch (final XMPPException e) {
            final String msg = "Error creating XMPP connection";
            log.error(msg);
            throw new RuntimeException(msg, e);
        }
    }

    public ChannelPipeline getPipeline() throws Exception {
        final ChannelPipeline pipeline = pipeline();

        synchronized (this) {
            while (this.conn == null) {
                wait(30000);
            }
        }

        if (this.conn == null) {
            log.error("No connection!!");
            throw new IllegalStateException("No XMPP connection");
        }
        
        // Uncomment the following line if you want HTTPS
        //SSLEngine engine = SecureChatSslContextFactory.getServerContext().createSSLEngine();
        //engine.setUseClientMode(false);
        //pipeline.addLast("ssl", new SslHandler(engine));
        
        // We want to allow longer request lines, headers, and chunks respectively.
        pipeline.addLast("decoder", new HttpRequestDecoder());
        pipeline.addLast("encoder", new HttpResponseEncoder());//new ProxyHttpResponseEncoder(cacheManager));
        pipeline.addLast("handler", 
            new HttpRequestHandler(this.channelGroup, 
                this.clientSocketChannelFactory, this.conn));
        
        newXmppConnection();
        return pipeline;
    }

    private void newXmppConnection() throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        final XMPPConnection conn = new XMPPConnection(config);
        conn.connect();
        conn.login(this.user, this.pwd);
        
        final Collection<String> mgJids = new HashSet<String>();
        final Roster roster = conn.getRoster();
        roster.addRosterListener(new RosterListener() {
            public void entriesDeleted(Collection<String> addresses) {}
            public void entriesUpdated(Collection<String> addresses) {}
            public void presenceChanged(final Presence presence) {
                final String from = presence.getFrom();
                if (from.startsWith("mglittleshoot@gmail.com")) {
                    System.out.println("PACKET: "+presence);
                    System.out.println(from);
                    if (presence.isAvailable()) {
                        mgJids.add(from);
                    }
                    else {
                        mgJids.remove(from);
                    }
                }
            }
            public void entriesAdded(final Collection<String> addresses) {
                System.out.println("Entries added: "+addresses);
            }
        });

        roster.createEntry("mglittleshoot@gmail.com", "MG Baby!", null);
        this.conn = conn;
        synchronized (this) {
            this.notifyAll();
        }
    }
}
