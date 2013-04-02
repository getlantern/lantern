package org.lantern.state;

import java.net.URI;
import java.util.Locale;

import org.apache.commons.lang3.time.FastDateFormat;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonSerialize.Inclusion;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternClientConstants;
import org.lantern.LanternRosterEntry;
import org.lantern.event.Events;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.lantern.util.LanternTrafficCounter;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
public class Peer {

    private String peerid = "";

    private String country = "";
    
    public enum Type {
        pc,
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

    private LanternTrafficCounter trafficCounter;
    
    private long bytesUp;
    
    private long bytesDn;
    
    private String version = "";

    private long lastConnectedLong;

    private LanternRosterEntry rosterEntry;

    private int port;
    
    public Peer() {
        
    }
    
    public Peer(final URI peerId,final String countryCode,
        final boolean mapped, final double latitude,
        final double longitude, final Type type,
        final String ip, final int port, final Mode mode, final boolean incoming,
        final LanternTrafficCounter trafficCounter,
        final LanternRosterEntry rosterEntry) {
        this.mapped = mapped;
        this.lat = latitude;
        this.lon = longitude;
        this.port = port;
        this.rosterEntry = rosterEntry;
        this.peerid = peerId.toASCIIString();
        this.ip = ip;
        this.mode = mode;
        this.incoming = incoming;
        this.type = type.toString();
        this.country = countryCode.toUpperCase(Locale.US);
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
        if (!this.trafficCounter.isConnected()) {
            return getBpsUpDn() > 0L;
        }
        return true;
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
            return trafficCounter.getCurrentWrittenBytes() * 
                LanternClientConstants.SYNC_INTERVAL_SECONDS;
        }
        return 0L;
    }

    @JsonView({Run.class})
    public long getBpsDown() {
        if (this.trafficCounter != null) {
            return trafficCounter.getCurrentReadBytes() * 
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
                //trafficCounter.getTrafficCounter().getCumulativeWrittenBytes();
            trafficCounter.getCumulativeWrittenBytes();
        }
        return this.bytesUp;
    }

    public void setBytesUp(long bytesUp) {
        this.bytesUp = bytesUp;
    }

    public long getBytesDn() {
        if (this.trafficCounter != null) {
            return bytesDn + 
                //trafficCounter.getTrafficCounter().getCumulativeReadBytes();
            trafficCounter.getCumulativeReadBytes();
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
    public LanternTrafficCounter getTrafficCounter() {
        return trafficCounter;
    }

    public void setTrafficCounter(
        final LanternTrafficCounter trafficCounter) {
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
    @JsonSerialize(include=Inclusion.NON_NULL)
    public String getLastConnected() {
        long lastConnected = getLastConnectedLong();
        if (lastConnected == 0) {
            return null;
        }
        return FastDateFormat.getInstance("yyyy-MM-dd' 'HH:mm:ss").format(
            lastConnected);
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
        Events.eventBus().post(new PeerLastConnectedChangedEvent(this));
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

    @JsonSerialize(include=Inclusion.NON_NULL)
    @JsonView({Run.class})
    public LanternRosterEntry getRosterEntry() {
        return rosterEntry;
    }

    public void setRosterEntry(LanternRosterEntry rosterEntry) {
        this.rosterEntry = rosterEntry;
    }

    @Override
    public String toString() {
        return "Peer [peerid=" + peerid + ", country=" + country + ", lat="
                + lat + ", lon=" + lon + ", type=" + type + ", online="
                + online + ", mapped=" + mapped + ", ip=" + ip + ", mode="
                + mode + ", incoming=" + incoming + ", trafficCounter="
                + trafficCounter + ", bytesUp=" + bytesUp + ", bytesDn="
                + bytesDn + ", version=" + version + ", lastConnectedLong="
                + lastConnectedLong + ", rosterEntry=" + rosterEntry + "]";
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

}
