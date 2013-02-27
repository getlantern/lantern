package org.lantern.state;

import java.util.Locale;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.state.Model.Run;
import org.lantern.util.LanternTrafficCounterHandler;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
public class Peer {

    private String userId = "";

    private String country = "";
    
    public enum Type {
        desktop,
        cloud,
        laeproxy
    }
    
    //private final Collection<PeerSocketWrapper> sockets = 
    //    new HashSet<PeerSocketWrapper>();

    //private final String base64Cert;

    private double latitude;

    private double longitude;
    
    private String type;
    
    private boolean online;

    private boolean mapped;

    private String ip = "";
    
    private Mode mode;
    
    private boolean incoming;

    private LanternTrafficCounterHandler trafficCounter;
    
    private long bytesUp;
    
    private long bytesDn;
    
    public Peer() {
        
    }
    
    public Peer(final String userId,
        final String countryCode, 
        final boolean mapped, final double latitude, 
        final double longitude, final Type type,
        final String ip, final Mode mode, final boolean incoming, 
        final LanternTrafficCounterHandler trafficCounter) {
        this.mapped = mapped;
        this.latitude = latitude;
        this.longitude = longitude;
        this.userId = userId;
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

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        this.country = country;
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public void setLongitude(double longitude) {
        this.longitude = longitude;
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
        if (getTrafficCounter() != null) {
            return trafficCounter.getTrafficCounter().getCurrentWrittenBytes();
        }
        return 0L;
    }

    @JsonView({Run.class})
    public long getBpsDown() {
        if (getTrafficCounter() != null) {
            return trafficCounter.getTrafficCounter().getCurrentReadBytes();
        }
        return 0L;
    }

    @JsonView({Run.class})
    public long getBpsUpDn() {
        return getBpsUp() + getBpsDown();
    }

    public long getBytesUp() {
        if (getTrafficCounter() != null) {
            return bytesUp + trafficCounter.getTrafficCounter().getCumulativeWrittenBytes();
        }
        return this.bytesUp;
    }

    public void setBytesUp(long bytesUp) {
        this.bytesUp = bytesUp;
    }

    public long getBytesDn() {
        if (getTrafficCounter() != null) {
            return bytesDn + trafficCounter.getTrafficCounter().getCumulativeReadBytes();
        }
        return this.bytesDn;
    }

    public void setBytesDn(long bytesDn) {
        this.bytesDn = bytesDn;
    }

    @JsonView({Run.class})
    public long getBytesUpDn() {
        if (getTrafficCounter() != null) {
            return getBytesUp() + getBytesDn();
        }
        return 0L;
    }

    @JsonIgnore
    public LanternTrafficCounterHandler getTrafficCounter() {
        return trafficCounter;
    }

    public void setTrafficCounter(final LanternTrafficCounterHandler trafficCounter) {
        this.trafficCounter = trafficCounter;
    }

}
