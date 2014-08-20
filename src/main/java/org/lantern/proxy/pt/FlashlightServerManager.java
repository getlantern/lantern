package org.lantern.proxy.pt;

import java.io.IOException;
import java.util.Properties;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.commons.httpclient.HttpStatus;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.client.fluent.Form;
import org.apache.http.client.fluent.Request;
import org.apache.http.client.fluent.Response;
import org.lantern.ConnectivityChangedEvent;
import org.lantern.LanternUtils;
import org.lantern.Messages;
import org.lantern.Shutdownable;
import org.lantern.Tr;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.Notification.MessageType;
import org.lantern.util.GatewayUtil;
import org.lantern.util.Threads;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.UpnpService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class FlashlightServerManager implements Shutdownable {

    private static final Logger LOGGER = LoggerFactory
            .getLogger(FlashlightServerManager.class);

    /**
     * Use internal port 443 plus myleshorton's lucky number 77.
     */
    private static final int PREFERRED_FLASHLIGHT_INTERNAL_PORT = 44377;
    private static final int FLASHLIGHT_EXTERNAL_PORT = 443;
    private static final long HEARTBEAT_PERIOD_MINUTES = 2;
    
    private final Model model;
    private final Messages msgs;
    private volatile Flashlight flashlight;
    private volatile ScheduledExecutorService heartbeat;
    
    @Inject
    public FlashlightServerManager(
            Model model,
            NatPmpService natPmpService,
            UpnpService upnpService,
            Messages messages) {
        LOGGER.info("Starting up...");
        this.model = model;
        this.msgs = messages;
        Events.register(this);
    }

    @Subscribe
    public void onModeChanged(ModeChangedEvent event) {
        boolean inGiveMode = event.getNewMode() == Mode.give;
        boolean isConnected = model.getConnectivity().isInternet();
        update(inGiveMode, isConnected);
    }

    @Subscribe
    public void onConnectivityChanged(
            final ConnectivityChangedEvent event) {
        boolean inGiveMode = LanternUtils.isGive();
        boolean isConnected = event.isConnected();
        update(inGiveMode, isConnected);
    }

    @Override
    synchronized public void stop() {
        LOGGER.debug("Flashlight manager closing.");
        stopFlashlight(model.getConnectivity().isInternet());
    }

    synchronized private void update(boolean inGiveMode, boolean isConnected) {
        boolean eligibleToRun = inGiveMode && isConnected;
        boolean running = flashlight != null;
        if (eligibleToRun && !running) {
            startFlashlight();
        } else if (!eligibleToRun && running) {
            stopFlashlight(isConnected);
        }
    }

    private void startFlashlight() {
        LOGGER.debug("Starting flashlight");
        try {
            runFlashlight(true);
        } catch (RuntimeException re) {
            if (re.getMessage().contains("Exit value: 50")) {
                LOGGER.warn("Unable to start flashlight with automatically mapped external port, try without mapping");
                runFlashlight(false);
            } else {
                throw re;
            }
        }

        heartbeat = Threads
                .newSingleThreadScheduledExecutor("FlashlightServerManager-Heartbeat");
        heartbeat.scheduleAtFixedRate(peerRegistrar,
                0,
                HEARTBEAT_PERIOD_MINUTES,
                TimeUnit.MINUTES);
    }

    private void stopFlashlight(boolean unregister) {
        LOGGER.debug("Stopping flashlight");
        if (unregister) {
            unregisterPeer();
        }
        if (heartbeat != null) {
            heartbeat.shutdownNow();
        }
        if (flashlight != null) {
            flashlight.stopServer();
        }
        heartbeat = null;
        flashlight = null;
    }

    private void runFlashlight(boolean mapExternalPort) {
        Properties props = new Properties();
        String instanceId = model.getInstanceId();
        props.setProperty(
                Flashlight.SERVER_KEY,
                instanceId + ".getiantem.org");
        if (mapExternalPort) {
            props.setProperty(
                    Flashlight.PORTMAP_KEY,
                    Integer.toString(FLASHLIGHT_EXTERNAL_PORT));
        }

        LOGGER.debug("Props: {}", props);
        flashlight = new Flashlight(props);
        int localPort = LanternUtils
                .findFreePort(PREFERRED_FLASHLIGHT_INTERNAL_PORT);
        flashlight.startServer(localPort, null);
    }

    private Runnable peerRegistrar = new Runnable() {
        @Override
        public void run() {
            boolean externallyAccessible = isFlashlightExternallyAccessible();
            if (externallyAccessible) {
                LOGGER.debug("Confirmed able to proxy for external clients!");
                hidePortMappingError();
                registerPeer();
            } else {
                LOGGER.warn("Unable to proxy for external clients!");
                showPortMappingError();
                unregisterPeer();
            }
        }
    };

    private void registerPeer() {
        Response response = null;
        try {
            response = Request
                    .Post(
                            "https://" + model.getS3Config().getDnsRegUrl()
                                    + "/register")
                    .bodyForm(
                            Form.form()
                                    .add("name", model.getInstanceId())
                                    .add("port",
                                            "" + FLASHLIGHT_EXTERNAL_PORT)
                                    .build())
                    .execute();
            if (response.returnResponse().getStatusLine().getStatusCode() != HttpStatus.SC_OK) {
                LOGGER.error("Unable to register peer: {}", response
                        .returnContent().asString());
            } else {
                LOGGER.debug("Registered peer");
            }
        } catch (IOException e) {
            LOGGER.error("Exception trying to register peer", e);
        } finally {
            if (response != null) {
                response.discardContent();
            }
        }
    }

    private void unregisterPeer() {
        Response response = null;
        try {
            response = Request
                    .Post("https://" + model.getS3Config().getDnsRegUrl()
                            + "/unregister")
                    .bodyForm(
                            Form.form().add("name", model.getInstanceId())
                                    .build())
                    .execute();
            if (response.returnResponse().getStatusLine().getStatusCode() != HttpStatus.SC_OK) {
                LOGGER.error("Unable to unregister peer: {}", response
                        .returnContent().asString());
            } else {
                LOGGER.debug("Unregistered peer");
            }
        } catch (IOException e) {
            LOGGER.error("Exception trying to unregister peer: " + e);
        } finally {
            if (response != null) {
                response.discardContent();
            }
        }
    }

    private boolean isFlashlightExternallyAccessible() {
        Response response = null;
        try {
            response = Request
                    .Get(model.getS3Config().getFlashlightCheckerUrl())
                    .execute();
            return response.returnResponse().getStatusLine().getStatusCode() == HttpStatus.SC_OK;
        } catch (IOException e) {
            LOGGER.error("Exception checking for externally accessible", e);
            return false;
        } finally {
            if (response != null) {
                response.discardContent();
            }
        }
    }

    private void showPortMappingError() {
        try {
            // Make sure there actually is an accessible gateway
            // screen before prompting the user to connect to it.
            final String gateway = GatewayUtil.defaultGateway();
            if (StringUtils.isNotBlank(gateway)) {
                msgs.msg(Tr.tr("BACKEND_MANUAL_NETWORK_PROMPT"),
                        MessageType.error, 0, true);
            }
        } catch (IOException e) {
            LOGGER.debug("Gateway may not exist", e);
        } catch (InterruptedException e) {
            LOGGER.debug("Gateway may not exist", e);
        }
    }
    
    private void hidePortMappingError() {
        msgs.closeMsg(Tr.tr("BACKEND_MANUAL_NETWORK_PROMPT"),
                MessageType.error);
    }

}
