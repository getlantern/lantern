package org.lantern.proxy;

import java.util.Properties;

import org.lantern.S3Config;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectedEvent;
import org.lantern.event.PublicIpEvent;
import org.lantern.proxy.pt.Flashlight;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * HTTP proxy server for local requests from the browser to Lantern (i.e. in Get
 * Mode).
 */
@Singleton
public class GetModeProxy extends AbstractHttpProxyServerAdapter {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(GetModeProxy.class);

    private final Flashlight fl;
    private final Model model;
    private volatile boolean started;
    private volatile boolean hasPublicIp;

    @Inject
    public GetModeProxy(
            Model model) {
        this.model = model;
        Properties props = new Properties();
        props.setProperty(Flashlight.CLOUDCONFIG_KEY,
                S3Config.DEFAULT_FLASHLIGHT_CLOUDCONFIG);
        props.setProperty(Flashlight.CLOUDCONFIG_CA_KEY,
                S3Config.DEFAULT_FLASHLIGHT_CLOUDCONFIG_CA);
        fl = new Flashlight(props);
        Events.register(this);
    }

    @Override
    synchronized public void start() {
        this.started = true;
        startWhenReady();
    }

    @Subscribe
    synchronized public void onPublicIp(PublicIpEvent pie) {
        this.hasPublicIp = true;
        startWhenReady();
    }

    private void startWhenReady() {
        if (started && hasPublicIp) {
            LOGGER.debug("Starting");
            doStart();
        } else {
            LOGGER.debug(
                    "Not yet ready to start. started: {}   hasPublicIp: {}",
                    started, hasPublicIp);
        }
    }
    
    /**
     * Don't call this, use start() unless you're testing.
     */
    public void doStart() {
        fl.startStandaloneClient();
        fl.addFallbackProxies(model.getS3Config().getFallbacks());
        Events.asyncEventBus().post(new ProxyConnectedEvent());
    }

    @Override
    synchronized public void stop() {
        fl.stopClient();
    }

    public void requireHighQOS() {
        fl.setMinQOS(Flashlight.HIGH_QOS);
    }

    public void unrequireHighQOS() {
        fl.setMinQOS(0);
    }

    @Subscribe
    public void onNewS3Config(final S3Config config) {
        LOGGER.info("Got new S3Config, sending {} fallbacks in flashlight",
                config.getFallbacks().size());
        fl.addFallbackProxies(config.getFallbacks());
    }
}
