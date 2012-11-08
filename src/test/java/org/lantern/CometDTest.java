package org.lantern;

import static org.junit.Assert.*;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import org.cometd.bayeux.Channel;
import org.cometd.bayeux.Message;
import org.cometd.bayeux.client.ClientSession;
import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.client.ClientSessionChannel.MessageListener;
import org.cometd.client.BayeuxClient;
import org.cometd.client.transport.ClientTransport;
import org.cometd.client.transport.LongPollingTransport;
import org.eclipse.jetty.client.HttpClient;
import org.junit.Test;

public class CometDTest {

    @Test
    public void test() throws Exception {
        LanternHub.settings().setApiPort(LanternUtils.randomPort());
        final int port = LanternHub.settings().getApiPort();
        startJetty();
        final HttpClient httpClient = new HttpClient();
        // Here set up Jetty's HttpClient, for example:
        // httpClient.setMaxConnectionsPerAddress(2);
        httpClient.start();

        // Prepare the transport
        final Map<String, Object> options = new HashMap<String, Object>();
        final ClientTransport transport = 
            LongPollingTransport.create(options, httpClient);

        final ClientSession session = 
            new BayeuxClient("http://127.0.0.1:"+port+"/cometd", transport);
        
        final AtomicBoolean handshake = new AtomicBoolean(false);
        session.getChannel(Channel.META_HANDSHAKE).addListener(
            new ClientSessionChannel.MessageListener() {
                @Override
                public void onMessage(final ClientSessionChannel channel,
                    final Message message) {
                    if (message.isSuccessful()) {
                        // Here handshake is successful
                        handshake.set(true);
                    }
                }
            });
        session.handshake();

        waitForBoolean("handshake", handshake);
        assertTrue("Could not handshake?", handshake.get());
        
        /*
        session.getChannel("/sync/settings").subscribe(new MessageListener() {
            
            @Override
            public void onMessage(final ClientSessionChannel channel, 
                final Message message) {
                System.err.println(message.getJSON());
            }
        });
        */
        
        final AtomicBoolean transferSync = new AtomicBoolean(false);
        final AtomicReference<String> transferPathKey = new AtomicReference<String>("");
        subscribe (session, transferSync, "transfers", transferPathKey);
        waitForBoolean("transfers", transferSync);
        assertEquals("Unexpected path key", "transfers", transferPathKey.get());
        
        final AtomicBoolean versionSync = new AtomicBoolean(false);
        final AtomicReference<String> versionPathKey = new AtomicReference<String>("");
        subscribe (session, versionSync, "version", versionPathKey);
        
        final Map<String,Object> updateJson = 
            new LinkedHashMap<String,Object>();
        updateJson.put(LanternConstants.UPDATE_VERSION_KEY, 0.20);
        updateJson.put(LanternConstants.UPDATE_RELEASED_KEY, 
            "2012-10-31T11:15:00Z");
        updateJson.put(LanternConstants.UPDATE_URL_KEY, 
            "http://s3.amazonaws.com/lantern/latest.dmg");
        updateJson.put(LanternConstants.UPDATE_MESSAGE_KEY, 
            "test update");
        
        LanternHub.asyncEventBus().post(new UpdateEvent(updateJson));
        
        waitForBoolean("version", versionSync);
        assertEquals("Unexpected path key", "version", versionPathKey.get());
    }

    private void subscribe(final ClientSession session, 
        final AtomicBoolean bool, final String channelName, 
        final AtomicReference<String> pathKey) {
        session.getChannel("/sync/"+channelName).subscribe(new MessageListener() {
            
            @Override
            public void onMessage(final ClientSessionChannel channel, 
                final Message message) {
                System.err.println(message.getJSON());
                final Map<String, Object> map = message.getDataAsMap();
                final String path = (String) map.get("path");
                System.err.println("Setting path key = "+path);
                pathKey.set(path);
                bool.set(true);
            }
        });
    }

    private void waitForBoolean(final String name, final AtomicBoolean bool) 
        throws InterruptedException {
        int tries = 0;
        while (tries < 200) {
            if (bool.get()) {
                break;
            }
            tries++;
            Thread.sleep(100);
        }
        assertTrue("Expected variable to be true: "+name, bool.get());
    }

    private void startJetty() throws Exception {
        final JettyLauncher jl = new JettyLauncher();
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                jl.start();
            }
        };
        final Thread jetty = new Thread(runner, "Jetty-Test-Thread");
        jetty.setDaemon(true);
        jetty.start();
        //Thread.sleep(5000);
        waitForServer(jl.getPort());
    }

    private void waitForServer(final int port) throws Exception {
        int attempts = 0;
        boolean connected = false;
        while (attempts < 200 && connected == false) {
            final Socket sock = new Socket();
            try {
                sock.connect(new InetSocketAddress("127.0.0.1", port), 1000);
                connected = true;
                System.err.println("Got connected!!");
            } catch (final IOException e) {
                //e.printStackTrace();
            }
            Thread.sleep(100);
            attempts++;
        }
        if (connected) {
            System.out.println("CONNECTED!!");
        } else {
            System.out.println("NOT CONNECTED!!");
        }
    }

}
