package org.lantern.proxy.pt;

import java.io.IOException;
import java.util.Properties;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.httpclient.HttpStatus;
import org.apache.http.client.fluent.Form;
import org.apache.http.client.fluent.Request;
import org.apache.http.client.fluent.Response;
import org.lantern.ConnectivityChangedEvent;
import org.lantern.LanternUtils;
import org.lantern.Shutdownable;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class FlashlightServerManager implements Shutdownable {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private Model model;
    private NatPmpService natPmpService;
    private UpnpService upnpService;

    private static final int FLASHLIGHT_EXTERNAL_PORT = 443;

    /**
     * Use internal port 443 plus myleshorton's lucky number 77.
     */
    private static final int PREFERRED_FLASHLIGHT_INTERNAL_PORT = 44377;

    private final AtomicBoolean portMappingMessageShown =
            new AtomicBoolean(false);

    private class State {

        private String myName() {
            String[] parts = getClass().getName().split("\\$");
            return parts[1];
        }

        public void onEnter() {
            log.debug("Entering " + myName());
        }

        public void onExit() {
            log.debug("Exiting " + myName());
        }

        public void exitTo(State newState) {
            onExit();
            state = newState;
            newState.onEnter();
        }

        public void onDisconnect() {
            exitTo(getDisconnectedState());
        }

        public void onConnected() {
            State disconnected = getDisconnectedState();
            exitTo(disconnected);
            disconnected.onConnected();
        }

        public void onEnterGiveMode() {
            throw new UnsupportedOperationException();
        }

        public void onExitGiveMode() {
            throw new UnsupportedOperationException();
        }
    }

    private class DisconnectedInGiveModeState extends State {

        @Override
        public void onExitGiveMode() {
            exitTo(new DisconnectedInNonGiveModeState());
        }

        @Override
        public void onConnected() {
            exitTo(new PortMappingState());
        }
    }

    private class DisconnectedInNonGiveModeState extends State {

        @Override
        public void onEnterGiveMode() {
            exitTo(new DisconnectedInGiveModeState());
        }

        @Override
        public void onConnected() {
            exitTo(new ConnectedInNonGiveModeState());
        }
    }

    private class ConnectedInNonGiveModeState extends State {

        @Override
        public void onEnterGiveMode() {
            exitTo(new PortMappingState());
        }
    }

    private class PortMappingState extends State {
        private int localPort;
        private boolean current;

        @Override
        public void onEnter() {
            super.onEnter();
            current = true;
            localPort = LanternUtils
                    .findFreePort(PREFERRED_FLASHLIGHT_INTERNAL_PORT);
            mapWithUPnP();
        }

        private void mapWithUPnP() {
            log.debug("Attempting to map to local port {} with UPnP", localPort);
            int result = upnpService.addUpnpMapping(
                    PortMappingProtocol.TCP,
                    localPort,
                    FLASHLIGHT_EXTERNAL_PORT,
                    upnpListener);
            if (result == -1) {
                mapWithNATPMP();
            }
        }

        private void mapWithNATPMP() {
            log.debug("Attempting to map to local port {} with NAT-PMP",
                    localPort);
            int result = natPmpService.addNatPmpMapping(
                    PortMappingProtocol.TCP,
                    localPort,
                    FLASHLIGHT_EXTERNAL_PORT,
                    natpmpListener);
            if (result == -1) {
                log.warn("Neither UPnP nor NAT-PMP seem to be enabled");
                synchronized (FlashlightServerManager.this) {
                    handlePortMapError();
                }
            }
        }

        @Override
        public void onExit() {
            current = false;
            super.onExit();
        }

        private PortMapListener upnpListener = new PortMapListener() {
            @Override
            public void onPortMap(int externalPort) {
                synchronized (FlashlightServerManager.this) {
                    log.debug("Got port mapped with UPnP: {}", externalPort);
                    if (externalPort != FLASHLIGHT_EXTERNAL_PORT) {
                        log.debug(
                                "Received invalid port mapping from UPnP, trying NAT-PMP: {}",
                                externalPort);
                        mapWithNATPMP();
                    } else {
                        portMappingResolved(FLASHLIGHT_EXTERNAL_PORT);
                    }
                }
            }

            @Override
            public void onPortMapError() {
                synchronized (FlashlightServerManager.this) {
                    log.debug("UPnP port map error, trying NAT-PMP");
                    mapWithNATPMP();
                }
            }
        };

        private PortMapListener natpmpListener = new PortMapListener() {
            @Override
            public void onPortMap(int externalPort) {
                synchronized (FlashlightServerManager.this) {
                    log.debug("Got port mapped with NAT-PMP: {}", externalPort);
                    if (externalPort != FLASHLIGHT_EXTERNAL_PORT) {
                        log.warn(
                                "Received invalid port mapping from NAT-PMP: {}",
                                externalPort);
                        handlePortMapError();
                    } else {
                        portMappingResolved(FLASHLIGHT_EXTERNAL_PORT);
                    }
                }
            }

            @Override
            public void onPortMapError() {
                synchronized (FlashlightServerManager.this) {
                    log.debug("NAT-PMP port map error");
                    handlePortMapError();
                }
            }
        };

        @Override
        public void onExitGiveMode() {
            exitTo(new ConnectedInNonGiveModeState());
        }

        private void handlePortMapError() {
            if (LanternUtils.isGive()) {
                if (!portMappingMessageShown.getAndSet(true)) {
                    log.debug("Show port mapping message only once");
                    model.setPortMappingError(true);
                }
                portMappingResolved(FLASHLIGHT_EXTERNAL_PORT);
            }
        }

        /**
         * We want to start Flashlight whether or not the port mapping
         * succeeded, as the user may manually configure their router to map the
         * correct port.
         * 
         * @param externalPort
         *            The externally mapped port (will just be 443 if the port
         *            has not been successfully mapped).
         */
        private void portMappingResolved(final int externalPort) {
            if (current) {
                exitTo(new PortMappedState(localPort, externalPort));
            } else {
                log.debug("Got port map, but I don't care anymore.");
                return;
            }
        }
    }

    private class PortMappedState extends State {

        private int localPort;
        private int externalPort;
        private Flashlight flashlight;
        // I don't suppose instanceId ever changes while Lantern is running,
        // but let's lean on the paranoid side and store it anyway, since it
        // needs to match for registrations and unregistrations in peerdnsreg.
        private String instanceId;
        private Timer timer;

        private static final long HEARTBEAT_PERIOD_MINUTES = 2;

        public PortMappedState(int localPort, int externalPort) {
            this.localPort = localPort;
            this.externalPort = externalPort;
        }

        @Override
        public void onEnter() {
            super.onEnter();
            log.debug("I'm port mapped at " + localPort + "<->" + externalPort);
            Properties props = new Properties();
            instanceId = model.getInstanceId();
            props.setProperty(
                    Flashlight.SERVER_KEY,
                    instanceId + ".getiantem.org");

            log.debug("Props: {}", props);
            flashlight = new Flashlight(props);
            flashlight.startServer(localPort, null);
            startHeartbeatTimer();
        }

        private void registerPeer() {
            Response response = null;
            try {
                response = Request.Post(
                        "https://" + model.getS3Config().getDnsRegUrl()
                                + "/register")
                        .bodyForm(Form.form().add("name", instanceId)
                                .add("port", "" + externalPort).build())
                        .execute();
                if (response.returnResponse().getStatusLine().getStatusCode() != HttpStatus.SC_OK) {
                    log.error("Unable to register peer: {}", response
                            .returnContent().asString());
                } else {
                    log.debug("Registered peer");
                }
            } catch (IOException e) {
                log.error("Exception trying to register peer: ", e);
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
                        .bodyForm(Form.form().add("name", instanceId).build())
                        .execute();
                if (response.returnResponse().getStatusLine().getStatusCode() != HttpStatus.SC_OK) {
                    log.error("Unable to unregister peer: {}", response
                            .returnContent().asString());
                } else {
                    log.debug("Unregistered peer");
                }
            } catch (IOException e) {
                log.error("Exception trying to unregister peer: " + e);
            } finally {
                if (response != null) {
                    response.discardContent();
                }
            }
        }

        private void startHeartbeatTimer() {
            log.debug("Starting heartbeat timer");
            timer = new Timer("Flashlight-Server-Manager-Heartbeat", true);
            timer.scheduleAtFixedRate(new TimerTask() {
                @Override
                public void run() {
                    registerPeer();
                }
            }, 0, HEARTBEAT_PERIOD_MINUTES * 60000);
        }

        private void stopHeartbeatTimer() {
            log.debug("Stopping heartbeat timer");
            if (timer != null) {
                timer.cancel();
                timer = null;
            }
        }

        @Override
        public void onExit() {
            stopHeartbeatTimer();
            unregisterPeer();
            flashlight.stopServer();
        }

        @Override
        public void onExitGiveMode() {
            exitTo(new ConnectedInNonGiveModeState());
        }
    }

    private State state;

    @Inject
    public FlashlightServerManager(
            Model model,
            NatPmpService natPmpService,
            UpnpService upnpService) {
        log.info("Flashlight port mapper starting up...");
        this.model = model;
        state = getDisconnectedState();
        this.natPmpService = natPmpService;
        this.upnpService = upnpService;
        Events.register(this);
        state.onEnter();
    }

    private State getDisconnectedState() {
        return model.getSettings().getMode() == Mode.give ?
                new DisconnectedInGiveModeState()
                : new DisconnectedInNonGiveModeState();
    }

    @Subscribe
    synchronized public void onConnectivityChanged(
            final ConnectivityChangedEvent event) {
        if (event.isConnected()) {
            log.debug("got connectivity");
            state.onConnected();
        } else {
            log.debug("lost connectivity");
            state.onDisconnect();
        }
    }

    @Subscribe
    synchronized public void onModeChanged(ModeChangedEvent event) {
        if (event.getNewMode() == Mode.give) {
            log.debug("enter give mode");
            state.onEnterGiveMode();
        } else {
            log.debug("exit give mode");
            state.onExitGiveMode();
        }
    }

    @Override
    synchronized public void stop() {
        log.debug("Flashlight manager closing.");
        state.onDisconnect();
    }
}
