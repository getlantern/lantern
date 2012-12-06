package org.lantern.state;

import java.net.InetAddress;
import java.security.SecureRandom;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.Censored;
import org.lantern.Country;
import org.lantern.LanternConstants;
import org.lantern.LanternHub;
import org.lantern.state.Settings.Mode;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


/**
 * State model of the application for the UI to display.
 */
public class Model {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public static class Persistent {}
    
    public static class Run {}
    
    private final SystemData system = new SystemData();
    
    private final Version version = new Version();
    
    private final Location location = new Location();
    
    private boolean showVis = false;
    
    private final boolean dev = false;
    
    private int ninvites = 0;
    
    private Modal modal = Modal.welcome;
    
    private Settings settings = new Settings();
    
    private Connectivity connectivity = new Connectivity();
    
    private Profile profile = new Profile();
    
    private boolean setupComplete;
    
    private int proxiedSitesMax = 2000;

    private boolean launchd;

    private boolean cache;
    
    private String nodeId = String.valueOf(new SecureRandom().nextLong());

    public Model() {
        threadPublicIpLookup();
    }
    
    /**
     * We thread this because otherwise looking up our public IP address 
     * over the network can delay the creation of settings altogether. That's
     * problematic if the UI is waiting on them, for example.
     */
    private void threadPublicIpLookup() {
        if (LanternConstants.ON_APP_ENGINE) {
            return;
        }
        final Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                // This performs the public IP lookup so by the time we set
                // GET versus GIVE mode we already know the IP and don't have
                // to wait.
                
                // We get the address here to set it in Connectivity.
                final InetAddress ip = 
                    new PublicIpAddress().getPublicIpAddress();
                if (ip == null) {
                    log.info("No IP -- possibly no internet connection");
                    return;
                }
                connectivity.setIp(ip.getHostAddress());
                
                final Censored cens = LanternHub.censored();
                // The IP is cached at this point.
                final Country count = cens.country();
                location.setCountry(count.getCode());
                if (StringUtils.isBlank(location.getCountry())) {
                    location.setCountry(count.getCode());
                }
                settings.setMode(cens.isCensored() ? Mode.get : Mode.give);
            }
            
        }, "Public-IP-Lookup-Thread");
        thread.setDaemon(true);
        thread.start();
    }
    public SystemData getSystem() {
        return system;
    }

    public Version getVersion() {
        return version;
    }

    public Location getLocation() {
        return location;
    }

    @JsonView({Run.class, Persistent.class})
    public Modal getModal() {
        return modal;
    }

    public void setModal(final Modal modal) {
        this.modal = modal;
    }

    public Settings getSettings() {
        return settings;
    }

    public void setSettings(final Settings settings) {
        this.settings = settings;
    }

    @JsonView({Run.class, Persistent.class})
    public int getNinvites() {
        return ninvites;
    }

    public void setNinvites(int ninvites) {
        this.ninvites = ninvites;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isShowVis() {
        return showVis;
    }
    
    public void setShowVis(boolean showVis) {
        this.showVis = showVis;
    }

    public Connectivity getConnectivity() {
        return connectivity;
    }

    public void setConnectivity(Connectivity connectivity) {
        this.connectivity = connectivity;
    }

    public boolean isDev() {
        return dev;
    }

    @JsonView({Run.class})
    public int getProxiedSitesMax() {
        return proxiedSitesMax;
    }

    public void setProxiedSitesMax(int proxiedSitesMax) {
        this.proxiedSitesMax = proxiedSitesMax;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isSetupComplete() {
        return setupComplete;
    }

    public void setSetupComplete(final boolean setupComplete) {
        this.setupComplete = setupComplete;
    }

    @JsonView({Run.class, Persistent.class})
    public Profile getProfile() {
        return profile;
    }

    public void setProfile(Profile profile) {
        this.profile = profile;
    }

    @JsonIgnore
    public boolean isLaunchd() {
        return launchd;
    }

    public void setLaunchd(boolean launchd) {
        this.launchd = launchd;
    }

    @JsonIgnore
    public boolean isCache() {
        return cache;
    }

    public void setCache(boolean cache) {
        this.cache = cache;
    }

    @JsonView({Run.class, Persistent.class})
    public String getNodeId() {
        return nodeId;
    }

    public void setNodeId(final String nodeId) {
        this.nodeId = nodeId;
    }
}
