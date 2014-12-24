package org.lantern.proxy.pt;

import java.io.IOException;
import java.util.Properties;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.httpclient.HttpStatus;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.time.DateUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.fluent.Form;
import org.apache.http.client.fluent.Request;
import org.apache.http.client.fluent.Response;
import org.apache.http.util.EntityUtils;
import org.lantern.ConnectivityChangedEvent;
import org.lantern.LanternClientConstants;
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
    private final AtomicBoolean needPortMappingWarning = new AtomicBoolean(true);
    private final AtomicBoolean connectivityCheckFailing = new AtomicBoolean();
    
    /**
     * The last time a mapping succeeded.
     */
    private long lastSuccessfulMapping = 0L;
    
    @Inject
    public FlashlightServerManager(
            Model model,
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
        if (!inGiveMode) {
            hidePortMappingSuccess();
            hidePortMappingWarning();
        }
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
        final Boolean internet = model.getConnectivity().isInternet();
        final boolean normalized;
        
        // The value for internet is initially null, so we need to account for
        // it.
        if (internet == null) {
            normalized = false;
        } else {
            normalized = internet.booleanValue();
        }
        stopFlashlight(normalized);
    }

    synchronized private void update(boolean inGiveMode, boolean isConnected) {
        boolean eligibleToRun = inGiveMode && isConnected;
        boolean running = flashlight != null;
        needPortMappingWarning.set(true);
        if (eligibleToRun && !running) {
            connectivityCheckFailing.set(false);
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
            final String msg = re.getMessage();
            if (msg != null && msg.contains("Exit value: 50")) {
                LOGGER.info("Unable to start flashlight with automatically mapped external port, try without mapping");
                runFlashlight(false);
            } else {
                LOGGER.error("Unexpected runtime exception", re);
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
        String externalPort = "0";
        if (mapExternalPort) {
            externalPort = Integer.toString(FLASHLIGHT_EXTERNAL_PORT);
        }
        props.setProperty(Flashlight.PORTMAP_KEY, externalPort);
        props.setProperty(Flashlight.WADDELL_ADDR_KEY, model.getS3Config().getWaddellAddr());
        
        LOGGER.debug("Props: {}", props);
        flashlight = new Flashlight(props);
        int localPort = LanternUtils
                .findFreePort(PREFERRED_FLASHLIGHT_INTERNAL_PORT);
        flashlight.startServer(localPort, null);
    }

    private Runnable peerRegistrar = new Runnable() {
        @Override
        public void run() {
            boolean externallyAccessible = registerPeer();
            if (externallyAccessible) {
                LOGGER.debug("Confirmed able to proxy for external clients!");
                hidePortMappingWarning();
                
                needPortMappingWarning.set(true);
                lastSuccessfulMapping = System.currentTimeMillis();
                if (connectivityCheckFailing.getAndSet(false)) {
                    showPortMappingSuccess();
                }
            } else {
                LOGGER.info("Unable to proxy for external clients!");
                connectivityCheckFailing.set(true);
                hidePortMappingSuccess();
                if (needPortMappingWarning.getAndSet(false) && 
                        shouldShowPortMappingFailure()) {
                    showPortMappingWarning();
                }
                unregisterPeer();
            }
        }
    };
    
    /**
     * Only should the failure message if the last successful mapping was 
     * sufficiently old.
     * 
     * @return <code>true</code> if we should show the mapping failure,
     * otherwise <code>false</code>
     */
    private boolean shouldShowPortMappingFailure() {
        return System.currentTimeMillis() - lastSuccessfulMapping >
            5 * DateUtils.MILLIS_PER_MINUTE;
    }

    private boolean registerPeer() {
        Response response = null;
        try {
            response = Request
                    .Post(
                            "https://" + model.getS3Config().getDnsRegUrl()+"/register")
                    .bodyForm(
                            Form.form()
                                    .add("name", model.getInstanceId())
                                    .add("port",
                                            "" + FLASHLIGHT_EXTERNAL_PORT)
                                            // Note - the below is only used for testing locally
                                            // The production dns registration service determines
                                            // the IP based on the network client/X-Forwarded-For
                                            // header.
                                            // model.getConnectivity().getIp() may actually return
                                            // null here since we may or may not have obtained a
                                            // public IP at this point.
                                    .add("ip", model.getConnectivity().getIp())
                                    .add("v", LanternClientConstants.VERSION)
                                    .build())
                    .connectTimeout(100 * 1000)
                    .socketTimeout(100 * 1000)
                    .execute();
            HttpResponse httpResponse = response.returnResponse();
            if (httpResponse.getStatusLine().getStatusCode() == HttpStatus.SC_OK) {
                LOGGER.info("Registered peer");
                return true;
            }
            LOGGER.error("Unable to register peer: {}", 
                    EntityUtils.toString(httpResponse.getEntity()));
        } catch (IOException e) {
            LOGGER.error("Exception trying to register peer", e);
        } finally {
            if (response != null) {
                response.discardContent();
            }
        }
        return false;
    }

    private void unregisterPeer() {
        Response response = null;
        try {
            response = Request
                    .Post("https://" + model.getS3Config().getDnsRegUrl() + "/unregister")
                    .bodyForm(
                            Form.form().add("name", model.getInstanceId())
                                    .build())
                    .connectTimeout(100 * 1000)
                    .socketTimeout(100 * 1000)
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

    private void showPortMappingWarning() {
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
    
    private void showPortMappingSuccess() {
        msgs.msg(Tr.tr("BACKEND_MANUAL_NETWORK_SUCCESS"),
                MessageType.success, 0, false);
    }
    
    private void hidePortMappingWarning() {
        msgs.closeMsg(Tr.tr("BACKEND_MANUAL_NETWORK_PROMPT"),
                MessageType.error);
    }
    
    private void hidePortMappingSuccess() {
        msgs.closeMsg(Tr.tr("BACKEND_MANUAL_NETWORK_SUCCESS"),
                MessageType.error);
    }

}
