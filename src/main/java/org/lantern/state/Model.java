package org.lantern.state;

import java.lang.reflect.Field;
import java.security.SecureRandom;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.codec.binary.Hex;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonDeserialize;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.Country;
import org.lantern.CountryService;
import org.lantern.LanternUtils;
import org.lantern.Roster;
import org.lantern.RosterDeserializer;
import org.lantern.RosterSerializer;
import org.lantern.S3Config;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.event.SetupCompleteEvent;
import org.lantern.monitoring.Stats;
import org.lantern.state.Notification.MessageType;


/**
 * State model of the application for the UI to display.
 */
@Keep
public class Model {

    public static class Persistent {}

    public static class Run {}

    private final SystemData system = new SystemData();

    private final Version version = new Version();

    private final Location location = new Location();

    private boolean showVis = false;

    private Modal modal = Modal.welcome;

    private Settings settings = new Settings();

    private Connectivity connectivity = new Connectivity();

    private Profile profile = new Profile();

    private boolean setupComplete;

    private int nproxiedSitesMax = 5000;

    private boolean launchd;

    private String nodeId = String.valueOf(new SecureRandom().nextLong());

    private Stats globalStats = new Stats();

    private Peers peerCollector = new Peers();

    private final ConcurrentHashMap<Integer, Notification> notifications = new ConcurrentHashMap<Integer, Notification>();

    private final AtomicInteger maxNotificationId = new AtomicInteger(0);

    private Roster roster;

    private InstanceStats instanceStats = new InstanceStats();

    private boolean isEverGetMode;

    private boolean welcomeMessageShown;

    private String xsrfToken;

    private CountryService countryService;
    
    private Set<String> dialogsToIgnore = new HashSet<String>();
    
    public Model() {
        //used for JSON loading
    }

    public Model(CountryService countryService) {
        this.countryService = countryService;
    }

    private String instanceId;
    
    private String userGuid;

    private String reportIp;

    private Collection<ClientFriend> friends;

    private int remainingFriendingQuota = 0;

    private S3Config s3Config = new S3Config();
    
    @JsonView({Run.class, Persistent.class})
    public InstanceStats getInstanceStats() {
        return instanceStats;
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

    @JsonView({Run.class})
    public Map<String, Country> getCountries() {
        return countryService.allCountries();
    }

    public void setCountries(Map<String, Country> countries) {
        //nothing to do here; we want to use the countryService
        return;
    }

    public Stats getGlobalStats() {
        return globalStats;
    }
    
    public void setGlobalStats(Stats globalStats) {
        this.globalStats = globalStats;
    }

    /*
    @JsonIgnore
    public FriendsHandler getFriends() {
        return friends;
    }

    public void setFriends(FriendsHandler friends) {
        this.friends = friends;
    }
    */

    @JsonView({Persistent.class})
    public Peers getPeerCollector() {
        return peerCollector;
    }

    public void setPeerCollector(Peers peerCollector) {
        this.peerCollector = peerCollector;
    }

    public void closeNotification(int notification) {
        synchronized(notifications) {
            notifications.remove(notification);
        }
    }
    
    /**
     * Closes all notifications with the same message as what's given.
     * 
     * @param message
     * @param type
     */
    public void closeNotifications(String message, MessageType type) {
        synchronized (notifications) {
            Iterator<Notification> it = notifications.values().iterator();
            while (it.hasNext()) {
                Notification existing = it.next();
                if (existing.getMessage().equals(message)) {
                    it.remove();
                }
            }
        }
    }

    public Map<Integer, Notification> getNotifications() {
        return notifications;
    }

    synchronized public void addNotification(Notification notification) {
        synchronized (notifications) {
            for (Notification existing : notifications.values()) {
                if (existing.getMessage().equals(notification.getMessage())) {
                    // Duplicate open notification, ignore
                    return;
                }
            }

            int oldMax = maxNotificationId.get();
            if (oldMax == 0) {
                // this happens at startup?
                for (Integer k : notifications.keySet()) {
                    if (k > oldMax)
                        oldMax = k + 1;
                }
                maxNotificationId.compareAndSet(0, oldMax);
            }
            int id = maxNotificationId.getAndIncrement();
            notifications.put(id, notification);
        }
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

    public void setInstanceStats(InstanceStats instanceStats) {
        this.instanceStats = instanceStats;
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

    @JsonIgnore
    public CountryService getCountryService() {
        return countryService;
    }

    public void setCountryService(CountryService countryService) {
        this.countryService = countryService;
    }

    @JsonView({Persistent.class})
    public boolean isWelcomeMessageShown() {
        return welcomeMessageShown;
    }

    public void setWelcomeMessageShown(boolean welcomeMessageShown) {
        this.welcomeMessageShown = welcomeMessageShown;
    }

    private String generateInstanceId() {
        final byte [] instanceIdBytes = new byte[16];
        SecureRandom secureRandom = new SecureRandom();
        secureRandom.nextBytes(instanceIdBytes);
        return Hex.encodeHexString(instanceIdBytes);
    }

    @JsonView({Persistent.class})
    public String getInstanceId() {
        if (instanceId == null) {
            instanceId = generateInstanceId();
        }
        return instanceId;
    }

    public void setInstanceId(String instanceId) {
        this.instanceId = instanceId;
    }
    
    /**
     * userGuid is a unique identifier for a user, assigned by the controller.
     * 
     * @return
     */
    @JsonView({ Persistent.class })
    public String getUserGuid() {
        return userGuid;
    }
    
    public void setUserGuid(String userGuid) {
        this.userGuid = userGuid;
    }

    @JsonView({Persistent.class})
    public String getReportIp() {
        return reportIp;
    }

    public void setReportIp(String reportIp) {
        this.reportIp = reportIp;
    }

    public void setFriends(Collection<ClientFriend> friends) {
        this.friends = friends;
    }
    
    @JsonView({Run.class})
    public Collection<ClientFriend> getFriends() {
        return this.friends;
    }
    
    public int getRemainingFriendingQuota() {
        return Math.max(remainingFriendingQuota, 0);
    }
    
    public void setRemainingFriendingQuota(int remainingFriendingQuota) {
        this.remainingFriendingQuota = remainingFriendingQuota;
    }

    @JsonView({Persistent.class})
    public S3Config getS3Config() {
        return this.s3Config;
    }

    public void setS3Config(final S3Config s3Config) {
        this.s3Config = s3Config;
    }

    public boolean shouldShowDialog(final String key) {
        return !dialogsToIgnore.contains(key);
    }

    public void doNotShowDialog(final String key) {
        this.dialogsToIgnore.add(key);
    }

    @JsonView({Persistent.class})
    public Set<String> getDialogsToIgnore() {
        return dialogsToIgnore;
    }

    public void setDialogsToIgnore(final Set<String> dialogsToIgnore) {
        this.dialogsToIgnore = dialogsToIgnore;
    }
    
}
