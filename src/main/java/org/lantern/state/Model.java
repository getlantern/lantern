package org.lantern.state;


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

    public SystemData getSystem() {
        return system;
    }

    public Version getVersion() {
        return version;
    }

    public Location getLocation() {
        return location;
    }

    public Modal getModal() {
        return modal;
    }

    public void setModal(Modal modal) {
        this.modal = modal;
    }

    public Settings getSettings() {
        return settings;
    }

    public void setSettings(final Settings settings) {
        this.settings = settings;
    }

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
    
}
