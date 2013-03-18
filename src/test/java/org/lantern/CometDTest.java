package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

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
import org.lantern.event.Events;
import org.lantern.event.UpdateEvent;
import org.lantern.http.JettyLauncher;
import org.lantern.state.StaticSettings;


public class CometDTest {

    @Test
    public void test() throws Exception {
        final int port = LanternUtils.randomPort();
        //RuntimeSettings.setApiPort(port);
        //LanternHub.settings().setApiPort(LanternUtils.randomPort());
        //final int port = LanternHub.settings().getApiPort();

        startJetty(TestUtils.getJettyLauncher(), port);
        final HttpClient httpClient = new HttpClient();
        // Here set up Jetty's HttpClient, for example:
        // httpClient.setMaxConnectionsPerAddress(2);
        httpClient.start();

        // Prepare the transport
        final Map<String, Object> options = new HashMap<String, Object>();
        final ClientTransport transport =
            LongPollingTransport.create(options, httpClient);

        final String url = StaticSettings.getLocalEndpoint()+"/cometd";
                final ClientSession session = new BayeuxClient(url, transport);

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
        waitForBoolean(handshake);
        assertTrue("Could not handshake?", handshake.get());

        final AtomicBoolean hasMessage = new AtomicBoolean(false);
        final AtomicReference<String> messagePath = new AtomicReference<String>("none");
        final MessageListener ml = new MessageListener() {

            @Override
            public void onMessage(final ClientSessionChannel channel,
                final Message message) {
                Object[] data = (Object[]) message.getData();
                @SuppressWarnings("unchecked")
                final Map<String, Object> map = (Map<String, Object>) data[0];
                //data.set(map);
                final String path = (String) map.get("path");
                messagePath.set(path);

                hasMessage.set(true);
            }
        };
        //final AtomicBoolean sync = new AtomicBoolean(false);
        //final AtomicReference<String> transferPathKey = new AtomicReference<String>("");
        subscribe (session, ml);
        waitForBoolean(hasMessage);
        assertEquals("", messagePath.get());
        hasMessage.set(false);
        messagePath.set("none");

        final Map<String,Object> updateJson =
            new LinkedHashMap<String,Object>();
        updateJson.put(LanternConstants.UPDATE_VERSION_KEY, 0.20);
        updateJson.put(LanternConstants.UPDATE_RELEASED_KEY,
            "2012-10-31T11:15:00Z");
        updateJson.put(LanternConstants.UPDATE_URL_KEY,
            "http://s3.amazonaws.com/lantern/latest.dmg");
        updateJson.put(LanternConstants.UPDATE_MESSAGE_KEY,
            "test update");

        Events.asyncEventBus().post(new UpdateEvent(updateJson));

        waitForBoolean(hasMessage);
        assertEquals("/version/latest", messagePath.get());
        hasMessage.set(false);
        messagePath.set("none");
    }

    private AtomicReference<Map<String, Object>> subscribe(
        final ClientSession session, final MessageListener ml) {

        final AtomicReference<Map<String, Object>> data =
            new AtomicReference<Map<String,Object>>();

        session.getChannel("/sync").subscribe(ml);
        return data;
    }

    private void waitForBoolean(final AtomicBoolean bool)
        throws InterruptedException {
        int tries = 0;
        while (tries < 40) {
            if (bool.get()) {
                break;
            }
            tries++;
            Thread.sleep(100);
        }
        assertTrue("Expected variable to be true", bool.get());
    }

    private void startJetty(final JettyLauncher jl, final int port) throws Exception {
        // The order of getting things from the injector matters unfortunately,
        // so we have to do the below.
        //injector.getInstance(DefaultXmppHandler.class);
        //final JettyLauncher jl = injector.getInstance(JettyLauncher.class);
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                jl.start();
            }
        };
        final Thread jetty = new Thread(runner, "Jetty-Test-Thread");
        jetty.setDaemon(true);
        jetty.start();
        LanternUtils.waitForServer(port, 6000);
    }
}
