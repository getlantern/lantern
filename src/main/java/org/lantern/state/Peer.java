package org.lantern.state;

import java.net.URI;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import org.apache.commons.lang3.time.FastDateFormat;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonSerialize.Inclusion;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternRosterEntry;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.proxy.ProxiedSitesList;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.lantern.util.Counter;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
@Keep
public class Peer {
    private String peerid = "";

    private String country = "";

    @Keep
    public enum Type {
        pc,
        cloud,
        laeproxy
    }

    // private final Collection<PeerSocketWrapper> sockets =
    // new HashSet<PeerSocketWrapper>();

    // private final String base64Cert;

    private double lat = 0.0;

    private double lon = 0.0;

    private Type type;

    private boolean online;

    private boolean mapped;

    private String ip = "";

    private boolean incoming;

    private long bytesUp;

    private Counter bytesUpCounter = Counter.averageOverOneSecond();

    private long bytesDn;

    private Counter bytesDnCounter = Counter.averageOverOneSecond();

    private String version = "";

    private LanternRosterEntry rosterEntry;

    private int port;

    private AtomicInteger numberOfOpenConnections = new AtomicInteger();

    private AtomicLong lastConnected = new AtomicLong(0L);

    private long lastConnectedLong;

    private volatile ProxiedSitesList proxiedSites = new ProxiedSitesList();

    public Peer() {

    }

    public Peer(final URI peerId, final String countryCode,
            final boolean mapped, final double latitude,
            final double longitude, final Type type,
            final String ip, final int port, final boolean incoming,
            final LanternRosterEntry rosterEntry, String[] proxiedSites) {
        this.mapped = mapped;
        this.lat = latitude;
        this.lon = longitude;
        this.port = port;
        this.rosterEntry = rosterEntry;
        this.peerid = peerId.toASCIIString();
        this.ip = ip;
        this.incoming = incoming;
        this.type = type;
        this.country = countryCode.toUpperCase(Locale.US);
        this.setProxiedSites(proxiedSites);

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

    @JsonIgnore
    public boolean hasGeoData() {
        return lat != 0.0 || lon != 0.0;
    }

    public Type getType() {
        return type;
    }

    public void setType(Type type) {
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

    @JsonView({ Run.class })
    public boolean isConnected() {
        return numberOfOpenConnections.get() > 0;
    }

    public boolean isIncoming() {
        return incoming;
    }

    public void setIncoming(boolean incoming) {
        this.incoming = incoming;
    }

    @JsonView({ Run.class })
    public long getBpsUp() {
        return bytesUpCounter.getRate();
    }

    @JsonView({ Run.class })
    public long getBpsDown() {
        return bytesDnCounter.getRate();
    }

    @JsonView({ Run.class })
    public long getBpsUpDn() {
        return getBpsUp() + getBpsDown();
    }

    public long getBytesUp() {
        return this.bytesUp + this.bytesUpCounter.getTotal();
    }

    public void setBytesUp(long bytesUp) {
        this.bytesUp = bytesUp;
    }

    public void addBytesUp(long numberOfBytes) {
        this.bytesUpCounter.add(numberOfBytes);
    }

    public long getBytesDn() {
        return this.bytesDn + this.bytesDnCounter.getTotal();
    }

    public void setBytesDn(long bytesDn) {
        this.bytesDn = bytesDn;
    }

    public void addBytesDn(long numberOfBytes) {
        this.bytesDnCounter.add(numberOfBytes);
    }

    @JsonView({ Run.class })
    public long getBytesUpDn() {
        return bytesDnCounter.getTotal() + bytesUpCounter.getTotal();
    }

    @JsonView({ Run.class })
    public int getNSockets() {
        return numberOfOpenConnections.get();
    }

    public void connected() {
        numberOfOpenConnections.incrementAndGet();
        lastConnected.set(System.currentTimeMillis());
    }

    public void disconnected() {
        numberOfOpenConnections.decrementAndGet();
    }

    @JsonView({ Run.class })
    @JsonSerialize(include = Inclusion.NON_NULL)
    public String getLastConnected() {
        long lastConnected = getLastConnectedLong();
        if (lastConnected == 0) {
            return null;
        }
        return FastDateFormat.getInstance("yyyy-MM-dd'T'HH:mm:ssZ").format(
                lastConnected);
    }

    @JsonView({ Persistent.class })
    public long getLastConnectedLong() {
        long result = lastConnected.get();
        if (result == 0l)
            result = lastConnectedLong;
        return result;
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

    @JsonSerialize(include = Inclusion.NON_NULL)
    // @JsonView({Run.class})
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
                + online + ", mapped=" + mapped + ", ip=" + ip
                + ", incoming=" + incoming + ", bytesUp=" + bytesUp
                + ", bytesDn=" + bytesDn + ", version=" + version
                + ", lastConnectedLong=" + lastConnectedLong + ", rosterEntry="
                + rosterEntry + "]";
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public void setProxiedSites(String[] proxiedSites) {
        this.proxiedSites = proxiedSites == null ?
                null : new ProxiedSitesList(proxiedSites);
    }

    /**
     * Determine whether or not this peer proxies the given host.
     * 
     * @param host
     * @return
     */
    public boolean proxiesHost(String host) {
        boolean isFallback = Type.cloud == this.type;
        boolean noProxiedSitesConfigured = proxiedSites == null;
        return isFallback || noProxiedSitesConfigured ||
                proxiedSites.includes(host);
    }
}
