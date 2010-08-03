package org.mg.client;


import static org.jboss.netty.channel.Channels.pipeline;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.util.Collection;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.Properties;
import java.util.Random;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.SmackConfiguration;
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

    private final String macAddress;
    
    private final LinkedBlockingQueue<ChannelPipeline> pipelines = 
        new LinkedBlockingQueue<ChannelPipeline>(NUM_CONNECTIONS);
    
    private static final int NUM_CONNECTIONS = 10;
    
    static {
        SmackConfiguration.setPacketReplyTimeout(20 * 1000);
    }
    
    /**
     * Separate thread for creating new XMPP connections.
     */
    private final ExecutorService connector = 
        Executors.newCachedThreadPool();
    
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
            
            final Enumeration<NetworkInterface> ints = 
                NetworkInterface.getNetworkInterfaces();
            this.macAddress = getMacAddress(ints);
        } catch (final IOException e) {
            final String msg = "Error loading props file at: " + file;
            log.error(msg);
            throw new RuntimeException(msg, e);
        }
        
        for (int i = 0; i < NUM_CONNECTIONS; i++) {
            threadedXmppConnection();
        }
    }

    private void persistentXmppConnection() {
        for (int i = 0; i < 10; i++) {
            try {
                log.info("Attempting XMPP connection...");
                newXmppConnection();
                log.info("Successfully connected...");
                return;
            } catch (final XMPPException e) {
                final String msg = "Error creating XMPP connection";
                log.error(msg, e);
            }
        }
    }

    private String getMacAddress(final Enumeration<NetworkInterface> nis) {
        while (nis.hasMoreElements()) {
            final NetworkInterface ni = nis.nextElement();
            try {
                final byte[] mac = ni.getHardwareAddress();
                if (mac.length > 0) {
                    return Base64.encodeBase64String(mac);
                }
            } catch (final SocketException e) {
                log.warn("Could not get MAC address?");
            }
        }
        try {
            return Base64.encodeBase64String(
                InetAddress.getLocalHost().getAddress()) + 
                System.currentTimeMillis();
        } catch (final UnknownHostException e) {
            final byte[] bytes = new byte[24];
            new Random().nextBytes(bytes);
            return Base64.encodeBase64String(bytes);
        }
    }

    public ChannelPipeline getPipeline() throws Exception {
        log.info("Getting pipeline...waiting for connection");
        final ChannelPipeline pipeline = this.pipelines.take();
        
        //final XMPPConnection conn = this.connections.take();
        

        
        // We create a new XMPP connection to give to the next incoming 
        // connection.
        threadedXmppConnection();
        return pipeline;
    }

    private void threadedXmppConnection() {
        connector.submit(new Runnable() {
            public void run() {
                persistentXmppConnection();
            }
        });
    }

    private void newXmppConnection() throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        config.setRosterLoadedAtLogin(true);
        
        final XMPPConnection xmpp = new XMPPConnection(config);
        xmpp.connect();
        xmpp.login(this.user, this.pwd, "MG");
        
        final Roster roster = xmpp.getRoster();
        final Collection<String> mgJids = new HashSet<String>();
        
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
                        synchronized (mgJids) {
                            mgJids.notifyAll();
                        }
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
        
        synchronized (mgJids) {
            while (mgJids.size() < 4) {
                try {
                    mgJids.wait(10000);
                } catch (final InterruptedException e) {
                    log.error("Interruped?", e);
                }
            }
        }
        final ChannelPipeline pipeline = pipeline();
        pipeline.addLast("handler", 
            new HttpRequestHandler(this.channelGroup, xmpp, 
                this.macAddress, mgJids));
        
        this.pipelines.add(pipeline);
    }
}
