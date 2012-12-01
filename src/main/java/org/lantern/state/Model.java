package org.lantern.state;

import org.codehaus.jackson.map.annotate.JsonView;


/**
 * State model of the application for the UI to display.
 * 
 * NOTE: We just always serialize all top-level elements.
 */
public class Model {

    public static class Persistent {}
    
    public static class Run {}
    
    private final SystemData system = new SystemData();
    
    private final Version version = new Version();
    
    private final Location location = new Location();
    
    private final boolean showVis = false;
    
    private final boolean dev = false;
    
    private int ninvites = 0;
    
    private Modal modal = Modal.welcome;
    
    private Settings settings = new Settings();
    
    private Connectivity connectivity = new Connectivity();
    
    private boolean setupComplete;
    
    private int proxiedSitesMax = 2000;

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

    public boolean isShowVis() {
        return showVis;
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
    
}
