package org.lantern.state;

import java.lang.reflect.Field;
import java.security.SecureRandom;
import java.util.Collection;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.codec.binary.Base64;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonDeserialize;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.Country;
import org.lantern.LanternUtils;
import org.lantern.Roster;
import org.lantern.RosterDeserializer;
import org.lantern.RosterSerializer;
import org.lantern.event.Events;
import org.lantern.event.InvitesChangedEvent;
import org.lantern.event.SetupCompleteEvent;
import org.lantern.state.Notification.MessageType;
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

    private int ninvites = -1;

    private Modal modal = Modal.welcome;

    private Settings settings = new Settings();

    private Connectivity connectivity = new Connectivity();

    private Profile profile = new Profile();

    private boolean setupComplete;

    private int nproxiedSitesMax = 2000;

    private boolean launchd;

    private boolean cache;

    private String nodeId = String.valueOf(new SecureRandom().nextLong());

    private Map<String, Country> countries = Country.allCountries();

    private final Global global = new Global();

    private Friends friends = new Friends();

    private Peers peerCollector = new Peers();

    private final ConcurrentHashMap<Integer, Notification> notifications = new ConcurrentHashMap<Integer, Notification>();

    private final AtomicInteger maxNotificationId = new AtomicInteger(0);

    private Roster roster;

    private Transfers transfers;

    private boolean isEverGetMode;

    private String xsrfToken;

    @JsonView({Run.class})
    private Transfers getTransfers() {
        return transfers;
    }

    @JsonView({Run.class})
    public Collection<Peer> getPeers() {
        return this.peerCollector.getPeers().values();
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
        int oldInvites = this.ninvites;
        this.ninvites = ninvites;
        if (oldInvites != ninvites) {
            Events.eventBus().post(new InvitesChangedEvent(oldInvites, ninvites));
        }
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

    @JsonView({Run.class})
    public boolean isDev() {
        return LanternUtils.isDevMode();
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isSetupComplete() {
        return setupComplete;
    }

    public void setSetupComplete(final boolean setupComplete) {
        this.setupComplete = setupComplete;
        if (setupComplete) {
            // Things like configuring the system proxy rely on setup being
            // complete, so propagate the event.
            Events.asyncEventBus().post(new SetupCompleteEvent());
        }
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

    @JsonView({Run.class})
    public int getNproxiedSitesMax() {
        return nproxiedSitesMax;
    }

    public void setNproxiedSitesMax(int nproxiedSitesMax) {
        this.nproxiedSitesMax = nproxiedSitesMax;
    }

    public Map<String, Country> getCountries() {
        return countries;
    }

    public void setCountries(Map<String, Country> countries) {
        this.countries = countries;
    }

    public Global getGlobal() {
        return global;
    }

    public Friends getFriends() {
        return friends;
    }

    public void setFriends(Friends friends) {
        this.friends = friends;
    }

    @JsonView({Persistent.class})
    public Peers getPeerCollector() {
        return peerCollector;
    }

    public void setPeerCollector(Peers peerCollector) {
        this.peerCollector = peerCollector;
    }

    public void closeNotification(int notification) {
        notifications.remove(notification);
    }

    public Map<Integer, Notification> getNotifications() {
        return notifications;
    }

    public void addNotification(String message, MessageType type, int timeout) {
        Notification notification = new Notification(message, type, timeout);
        addNotification(notification);
    }

    public void addNotification(String message, MessageType type) {
        addNotification(new Notification(message, type));
    }

    public void addNotification(Notification notification) {
        int oldMax = maxNotificationId.get();
        if (oldMax == 0) {
            //this happens at startup?
            for (Integer k : notifications.keySet()) {
                if (k > oldMax)
                    oldMax = k+1;
            }
            maxNotificationId.compareAndSet(0, oldMax);
        }
        int id = maxNotificationId.getAndIncrement();
        notifications.put(id, notification);
    }

    public void clearNotifications() {
        notifications.clear();
    }

    @JsonView({Run.class})
    @JsonSerialize(using=RosterSerializer.class)
    @JsonDeserialize(using=RosterDeserializer.class)
    public Roster getRoster() {
        return roster;
    }

    public void setRoster(Roster roster) {
        this.roster = roster;
    }

    public void setTransfers(Transfers transfers) {
        this.transfers = transfers;
    }

    @SuppressWarnings("unchecked")
    public void loadFrom(Model newModel) {
        Class<Model> modelClass = (Class<Model>) getClass();
        try {

            for (Field field : modelClass.getFields()) {
                field.set(this, field.get(newModel));
            }
        } catch (IllegalArgumentException e) {
            throw new RuntimeException(e);
        } catch (IllegalAccessException e) {
            throw new RuntimeException(e);
        }

    }

    public boolean isEverGetMode() {
        return isEverGetMode;
    }

    public void setEverGetMode(boolean b) {
        this.isEverGetMode = b;
    }

    public String getXsrfToken() {
        if (xsrfToken == null) {
            byte[] bytes = new byte[16];
            new SecureRandom().nextBytes(bytes);
            xsrfToken = Base64.encodeBase64URLSafeString(bytes);
        }
        return xsrfToken;
    }

    public void setXsrfToken(String token) {
        xsrfToken = token;
    }
}
