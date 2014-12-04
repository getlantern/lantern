package org.lantern.proxy;

import io.netty.handler.codec.http.HttpRequest;

import java.util.Properties;

import org.lantern.ConnectivityStatus;
import org.lantern.LanternConstants;
import org.lantern.S3Config;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.proxy.pt.Flashlight;
import org.lantern.state.InstanceStats;
import org.lantern.state.Model;
import org.littleshoot.proxy.ActivityTrackerAdapter;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.FullFlowContext;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * HTTP proxy server for local requests from the browser to Lantern (i.e. in Get
 * Mode).
 */
@Singleton
public class GetModeProxy extends AbstractHttpProxyServerAdapter {
    private final Flashlight fl;
    
    @Inject
    public GetModeProxy(
            Model model,
            ChainedProxyManager chainedProxyManager,
            GetModeProxyFilter filter) {
        Properties props = new Properties();
        props.setProperty(Flashlight.CLOUDCONFIG_KEY, S3Config.DEFAULT_FLASHLIGHT_CLOUDCONFIG);
        props.setProperty(Flashlight.CLOUDCONFIG_CA_KEY, S3Config.DEFAULT_FLASHLIGHT_CLOUDCONFIG_CA);
        fl = new Flashlight(props);
        Events.register(this);
    }
    
    @Override
    synchronized public void start() {
        fl.startStandaloneClient();
        Events.asyncEventBus().post(new ProxyConnectionEvent(ConnectivityStatus.CONNECTED));
    }
    
    @Override
    synchronized public void stop() {
        fl.stopClient();
    }
    
    @Subscribe
    public void onNewS3Config(final S3Config config) {
        
    }
    
    private void addFallbackProxies() {
        
    }
}
