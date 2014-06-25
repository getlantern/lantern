package org.lantern.proxy.pt;

import java.io.IOException;
import java.util.Properties;

import org.lantern.ConnectivityChangedEvent;
import org.lantern.LanternUtils;
import org.lantern.Shutdownable;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.event.PublicIpEvent;
import org.lantern.state.Mode;
import org.lantern.state.Model;

import org.apache.commons.lang3.StringUtils;
import org.apache.http.client.fluent.Form;
import org.apache.http.client.fluent.Request;
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

    private class State {

        public void onEnter() {
            log.debug("Entering " + getClass().getName());
        }

        public void onExit() {
            log.debug("Exiting " + getClass().getName());
        }

        public void exitTo(State newState) {
            onExit();
            state = newState;
            newState.onEnter();
        }

        public void onDisconnect() {
            exitTo(getDisconnectedState());
        }

        public void onPublicIp(String ip) {
            State disconnected = getDisconnectedState();
            exitTo(disconnected);
            disconnected.onPublicIp(ip);
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
        public void onPublicIp(String ip) {
            exitTo(new PortMappingState(ip));
        }
    }

    private class DisconnectedInNonGiveModeState extends State {
        @Override
        public void onEnterGiveMode() {
            exitTo(new DisconnectedInGiveModeState());
        }
        @Override
        public void onPublicIp(String ip) {
            exitTo(new ConnectedInNonGiveModeState(ip));
        }
    }

    private class ConnectedInNonGiveModeState extends State {
        private String ip;
        public ConnectedInNonGiveModeState(String ip) {
            this.ip = ip;
        }
        @Override
        public void onEnterGiveMode() {
            exitTo(new PortMappingState(ip));
        }
    }

    private class PortMappingState extends State implements PortMapListener {
        private String ip;
        private int localPort;
        boolean current;
        public PortMappingState(String ip) {
            this.ip = ip;
        }
        @Override
        public void onEnter() {
            super.onEnter();
            current = true;
            localPort = LanternUtils.findFreePort();
            upnpService.addUpnpMapping(
                    PortMappingProtocol.TCP,
                    localPort,
                    localPort,
                    PortMappingState.this);
            natPmpService.addNatPmpMapping(
                    PortMappingProtocol.TCP,
                    localPort,
                    localPort,
                    PortMappingState.this);
        }
        @Override
        public void onExit() {
            current = false;
            super.onExit();
        }
        @Override
        public void onPortMap(final int externalPort) {
            if (current) {
                exitTo(new PortMappedState(ip, localPort, externalPort));
            } else {
                log.debug("Got port map, but I don't care anymore.");
                return;
            }
        }
        @Override
        public void onPortMapError() {
            if (current) {
                log.debug("Got port map error.");
            }
        }
        @Override
        public void onExitGiveMode() {
            exitTo(new ConnectedInNonGiveModeState(ip));
        }
    }

    private class PortMappedState extends State {
        private String ip;
        private int localPort;
        private int externalPort;
        private Flashlight flashlight;
        // I don't suppose instanceId ever changes while Lantern is running,
        // but let's lean on the paranoid side and store it anyway, since it
        // needs to match for registrations and unregistrations in peerdnsreg.
        private String instanceId;
        public PortMappedState(String ip, int localPort, int externalPort) {
            this.ip = ip;
            this.localPort = localPort;
            this.externalPort = externalPort;
        }
        @Override
        public void onEnter() {
            super.onEnter();
            log.debug("I'm port mapped at "
                      + ip + ":" + localPort + "<->" + externalPort);
            Properties props = new Properties();
            instanceId = model.getInstanceId();
            props.setProperty(
                    Flashlight.SERVER_KEY,
                    instanceId + ".getiantem.org");
            flashlight = new Flashlight(props);
            flashlight.startServer(localPort, null);
            registerPeer();
            startHeartbeatTimer();
        }

        private void registerPeer() {
            try {
                Request.Post("https://peerdnsreg.herokuapp.com/register")
                       .bodyForm(Form.form().add("name", instanceId)
                                            .add("ip", ip)
                                            .add("port", "" + externalPort).build())
                       .execute().returnContent();
            } catch (IOException e) {
                log.error("Exception trying to register peer: " + e);
            }
        }

        private void unregisterPeer() {
            try {
                Request.Post("https://peerdnsreg.herokuapp.com/unregister")
                       .bodyForm(Form.form().add("name", instanceId).build())
                       .execute().returnContent();
            } catch (IOException e) {
                log.error("Exception trying to register peer: " + e);
            }
        }

        private void startHeartbeatTimer() {
            log.debug("Now I would start the heartbeat timer");
        }

        private void stopHeartbeatTimer() {
            log.debug("Now I would stop the heartbeat timer");
        }

        @Override
        public void onExit() {
            stopHeartbeatTimer();
            unregisterPeer();
            flashlight.stopServer();
        }

        @Override
        public void onExitGiveMode() {
            exitTo(new ConnectedInNonGiveModeState(ip));
        }
    }

    State state;

    @Inject
    public FlashlightServerManager(
            Model model,
            NatPmpService natPmpService,
            UpnpService upnpService) {
        log.warn("Flashlight port mapper starting up...");
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
    public void onPublicIp(final PublicIpEvent publicIpEvent) {
        log.debug("IP event");
        refreshConnectionState();
    }

    @Subscribe
    public void onConnectivityChanged(final ConnectivityChangedEvent event) {
        if (event.isConnected()) {
            log.debug("got connectivity");
            refreshConnectionState();
        } else {
            log.debug("lost connectivity");
            state.onDisconnect();
        }
    }

    private void refreshConnectionState() {
        String ip = model.getConnectivity().getIp();
        if (StringUtils.isBlank(ip)) {
            // For our purposes this is equivalent to a disconnection.
            state.onDisconnect();
        } else {
            state.onPublicIp(ip);
        }
    }

    @Subscribe
    public void onModeChanged(ModeChangedEvent event) {
        if (event.getNewMode() == Mode.give) {
            state.onEnterGiveMode();
        } else {
            state.onExitGiveMode();
        }
    }

    @Override
    public void stop() {
        log.debug("Flashlight manager closing.");
        state.onDisconnect();
    }
}
