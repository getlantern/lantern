package org.lantern.state;

import java.util.Locale;

import org.apache.commons.lang3.time.FastDateFormat;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternClientConstants;
import org.lantern.LanternRosterEntry;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.lantern.util.LanternTrafficCounterHandler;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
public class Peer {

    private String peerid = "";

    private String country = "";
    
    public enum Type {
        desktop,
        cloud,
        laeproxy
    }
    
    //private final Collection<PeerSocketWrapper> sockets = 
    //    new HashSet<PeerSocketWrapper>();

    //private final String base64Cert;

    private double lat;

    private double lon;
    
    private String type;
    
    private boolean online;

    private boolean mapped;

    private String ip = "";
    
    private Mode mode;
    
    private boolean incoming;

    private LanternTrafficCounterHandler trafficCounter;
    
    private long bytesUp;
    
    private long bytesDn;
    
    private String version = "";

    private long lastConnectedLong;

    private LanternRosterEntry rosterEntry;
    
    public Peer() {
        
    }
    
    public Peer(final String userId,
        final String countryCode, 
        final boolean mapped, final double latitude, 
        final double longitude, final Type type,
        final String ip, final Mode mode, final boolean incoming, 
        final LanternTrafficCounterHandler trafficCounter, 
        final LanternRosterEntry rosterEntry) {
        this.mapped = mapped;
        this.lat = latitude;
        this.lon = longitude;
        this.rosterEntry = rosterEntry;
        this.setPeerid(userId);
        this.ip = ip;
        this.mode = mode;
        this.incoming = incoming;
        this.type = type.toString();
        this.country = countryCode.toLowerCase(Locale.US);
        this.trafficCounter = trafficCounter;
        
        // Peers are online when constructed this way (because we presumably 
        // just received some type of message from them).
        this.online = true;
    }

    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        this.country = country;
    }

    public double getLat() {
        return lat;
    }

    public void setLat(double latitude) {
        this.lat = latitude;
    }

    public double getLon() {
        return lon;
    }

    public void setLon(double longitude) {
        this.lon = longitude;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public boolean isOnline() {
        return online;
    }

    public void setOnline(boolean online) {
        this.online = online;
    }

    public boolean isMapped() {
        return mapped;
    }

    public void setMapped(boolean mapped) {
        this.mapped = mapped;
    }

    public String getIp() {
        return ip;
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    public Mode getMode() {
        return mode;
    }

    public void setMode(Mode mode) {
        this.mode = mode;
    }

    @JsonView({Run.class})
    public boolean isConnected() {
        if (this.trafficCounter == null) {
            return false;
        }
        return this.trafficCounter.isConnected();
    }


    public boolean isIncoming() {
        return incoming;
    }

    public void setIncoming(boolean incoming) {
        this.incoming = incoming;
    }

    @JsonView({Run.class})
    public long getBpsUp() {
        if (this.trafficCounter != null) {
            return trafficCounter.getTrafficCounter().getCurrentWrittenBytes() * 
                LanternClientConstants.SYNC_INTERVAL_SECONDS;
        }
        return 0L;
    }

    @JsonView({Run.class})
    public long getBpsDown() {
        if (this.trafficCounter != null) {
            return trafficCounter.getTrafficCounter().getCurrentReadBytes() * 
                LanternClientConstants.SYNC_INTERVAL_SECONDS;
        }
        return 0L;
    }

    @JsonView({Run.class})
    public long getBpsUpDn() {
        return getBpsUp() + getBpsDown();
    }

    public long getBytesUp() {
        if (this.trafficCounter != null) {
            return bytesUp + 
                trafficCounter.getTrafficCounter().getCumulativeWrittenBytes();
        }
        return this.bytesUp;
    }

    public void setBytesUp(long bytesUp) {
        this.bytesUp = bytesUp;
    }

    public long getBytesDn() {
        if (this.trafficCounter != null) {
            return bytesDn + 
                trafficCounter.getTrafficCounter().getCumulativeReadBytes();
        }
        return this.bytesDn;
    }

    public void setBytesDn(long bytesDn) {
        this.bytesDn = bytesDn;
    }

    @JsonView({Run.class})
    public long getBytesUpDn() {
        if (this.trafficCounter != null) {
            return getBytesUp() + getBytesDn();
        }
        return 0L;
    }

    @JsonIgnore
    public LanternTrafficCounterHandler getTrafficCounter() {
        return trafficCounter;
    }

    public void setTrafficCounter(
        final LanternTrafficCounterHandler trafficCounter) {
        this.trafficCounter = trafficCounter;
    }

    @JsonView({Run.class})
    public int getNSockets() {
        if (this.trafficCounter != null) {
            return trafficCounter.getNumSockets();
        }
        return 0;
    }
    
    @JsonView({Run.class})
    public String getLastConnected() {
        return FastDateFormat.getInstance("yyyy-MM-dd' 'HH:mm:ss").format(
            getLastConnectedLong()); 
    }
    
    @JsonView({Persistent.class})
    public long getLastConnectedLong() {
        if (this.trafficCounter != null) {
            final long last = trafficCounter.getLastConnected();
            
            // Only use the counter data if it has connected.
            if (last > 0L) return last;
        }
        return this.lastConnectedLong;
    }
    
    public void setLastConnectedLong(final long lastConnectedLong) {
        this.lastConnectedLong = lastConnectedLong;
    }

    public String getPeerid() {
        return peerid;
    }

    public void setPeerid(String peerid) {
        this.peerid = peerid;
    }

    public String getVersion() {
        return version;
    }

    public void setVersion(String version) {
        this.version = version;
    }

    public LanternRosterEntry getRosterEntry() {
        return rosterEntry;
    }

    public void setRosterEntry(LanternRosterEntry rosterEntry) {
        this.rosterEntry = rosterEntry;
    }

}
