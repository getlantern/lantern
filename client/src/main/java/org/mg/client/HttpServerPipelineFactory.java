package org.mg.client;


import static org.jboss.netty.channel.Channels.pipeline;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Properties;

import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Presence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Factory for creating pipelines for incoming requests to our listening
 * socket.
 */
public class HttpServerPipelineFactory implements ChannelPipelineFactory {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ChannelGroup channelGroup;
    
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
        //pipeline.addLast("decoder", new HttpRequestDecoder());
        //pipeline.addLast("encoder", new HttpResponseEncoder());//new ProxyHttpResponseEncoder(cacheManager));
        pipeline.addLast("handler", 
            new HttpRequestHandler(this.channelGroup, this.conn));
        
        // We create a new XMPP connection to give to the next incoming 
        // connection.
        newXmppConnection();
        return pipeline;
    }

    private void newXmppConnection() throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        final XMPPConnection xmpp = new XMPPConnection(config);
        xmpp.connect();
        xmpp.login(this.user, this.pwd, "MG");
        
        final Collection<String> mgJids = new HashSet<String>();
        final Roster roster = xmpp.getRoster();
        roster.addRosterListener(new RosterListener() {
            public void entriesDeleted(Collection<String> addresses) {}
            public void entriesUpdated(Collection<String> addresses) {}
            public void presenceChanged(final Presence presence) {
                final String from = presence.getFrom();
                if (from.startsWith("mglittleshoot@gmail.com")) {
                    log.info("PACKET: "+presence);
                    log.info("Packet is from: {}", from);
                    if (presence.isAvailable()) {
                        mgJids.add(from);
                    }
                    else {
                        log.info("Removing connection with status {}", 
                            presence.getStatus());
                        mgJids.remove(from);
                    }
                }
            }
            public void entriesAdded(final Collection<String> addresses) {
                log.info("Entries added: "+addresses);
            }
        });

        // Make sure we look for MG packets.
        roster.createEntry("mglittleshoot@gmail.com", "MG", null);
        this.conn = xmpp;
        synchronized (this) {
            this.notifyAll();
        }
    }
}
