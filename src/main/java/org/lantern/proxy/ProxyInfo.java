package org.lantern.proxy;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.UnknownHostException;
import java.util.HashSet;
import java.util.Properties;
import java.util.Set;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.lantern.proxy.pt.PtType;
import org.lantern.state.Peer.Type;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;

@JsonIgnoreProperties(ignoreUnknown = true)
public class ProxyInfo {

    /**
     * The jid of the user hosting this proxy
     */
    protected URI jid;

    /**
     * Type type of proxy
     */
    protected Type type = Type.pc;

    /**
     * The host (ip or dns name) at which this proxy is availble on the
     * internet.
     */
    protected String wanHost;

    /**
     * The port at which this proxy is availble on the internet.
     */
    protected int wanPort;

    /**
     * The host (ip or dns name) at which this proxy is available on its LAN.
     */
    protected String lanHost;

    /**
     * The port at which this proxy is available on its LAN.
     */
    protected int lanPort;

    /**
     * The local address from which we're bound to this proxy (used for NAT
     * traversal).
     */
    @JsonIgnore
    protected InetSocketAddress boundFrom;

    /**
     * Whether or not we should use the lan address rather than the wan address
     * for this proxy.
     */
    protected boolean useLanAddress = false;

    /**
     * The {@link Protocol} which this proxy uses for clients.
     */
    protected Protocol protocol = Protocol.TCP;

    /**
     * The authToken used by this proxy to authenticate its clients.
     */
    protected String authToken;

    /**
     * The certificate by which this proxy identifies itself to clients.
     */
    protected String cert;

    /**
     * Configuration for pluggable transport
     */
    protected Properties pt;
    
    private int priority = 0;
    
    private Set<Integer> limitedToPorts = new HashSet<Integer>();

    public ProxyInfo() {
    }

    public ProxyInfo(URI jid) {
        this.jid = jid;
    }

    public ProxyInfo(URI jid, String wanHost, int wanPort) {
        this(jid);
        this.wanHost = wanHost;
        this.wanPort = wanPort;
    }

    public ProxyInfo(URI jid, Type type, String wanHost, int wanPort,
            String lanHost, int lanPort, InetSocketAddress boundFrom,
            boolean useLanAddress, Protocol protocol, String authToken,
            String cert, Properties pt) {
        super();
        this.jid = jid;
        this.type = type;
        this.wanHost = wanHost;
        this.wanPort = wanPort;
        this.lanHost = lanHost;
        this.lanPort = lanPort;
        this.boundFrom = boundFrom;
        this.useLanAddress = useLanAddress;
        this.protocol = protocol;
        this.authToken = authToken;
        this.cert = cert;
        this.pt = pt;
    }

    /**
     * Returns this ProxyInfo, with {@link #useLanAddress} set to true.
     * 
     * @return
     */
    public ProxyInfo onLan() {
        return new ProxyInfo(jid, type, wanHost, wanPort, lanHost, lanPort,
                boundFrom, true, protocol, authToken, cert, pt);
    }

    public URI getJid() {
        return jid;
    }

    public void setJid(URI jid) {
        this.jid = jid;
    }

    public Type getType() {
        return type;
    }

    public void setType(Type type) {
        this.type = type;
    }

    @JsonIgnore
    public boolean isNatTraversed() {
        return useLanAddress ? lanAddress() == null : wanAddress() == null;
    }

    public InetSocketAddress wanAddress() {
        if (wanHost == null || wanPort == 0) {
            return null;
        } else {
            try {
                InetAddress host = InetAddress.getByName(wanHost);
                // We've seen this in weird cases in the field -- might as well
                // program defensively here.
                if (host.isLoopbackAddress()
                        || host.isAnyLocalAddress()) {
                    return null;
                } else {
                    return new InetSocketAddress(
                            host,
                            wanPort);
                }
            } catch (UnknownHostException uhe) {
                throw new RuntimeException(uhe);
            }
        }
    }

    public String getWanHost() {
        return wanHost;
    }

    public void setWanHost(String host) {
        this.wanHost = host;
    }

    public int getWanPort() {
        return wanPort;
    }

    public void setWanPort(int port) {
        this.wanPort = port;
    }

    public InetSocketAddress lanAddress() {
        if (wanHost == null || wanPort == 0) {
            return null;
        } else {
            try {
                return new InetSocketAddress(InetAddress.getByName(wanHost),
                        wanPort);
            } catch (UnknownHostException uhe) {
                throw new RuntimeException(uhe);
            }
        }
    }

    public String getLanHost() {
        return lanHost;
    }

    public void setLanHost(String host) {
        this.lanHost = host;
    }

    public int getLanPort() {
        return lanPort;
    }

    public void setLanPort(int lanPort) {
        this.lanPort = lanPort;
    }

    public InetSocketAddress getBoundFrom() {
        return boundFrom;
    }

    public void setBoundFrom(InetSocketAddress boundFrom) {
        this.boundFrom = boundFrom;
    }

    public boolean isUseLanAddress() {
        return useLanAddress;
    }

    public void setUseLanAddress(boolean useLanAddress) {
        this.useLanAddress = useLanAddress;
    }

    public Protocol getProtocol() {
        return protocol;
    }

    public void setProtocol(Protocol protocol) {
        this.protocol = protocol;
    }

    public String getAuthToken() {
        return authToken;
    }

    public void setAuthToken(String authToken) {
        this.authToken = authToken;
    }

    public String getCert() {
        return cert;
    }

    public void setCert(String cert) {
        this.cert = cert;
    }

    public Properties getPt() {
        return pt;
    }
    
    public void setPt(Properties pt) {
        this.pt = pt;
    }
    
    public PtType getPtType() {
        if (pt == null) {
            return null;
        } else {
            return PtType.valueOf(pt.getProperty("type").toUpperCase());
        }
    }

    /**
     * Get a {@link FiveTuple} corresponding to this {@link ProxyInfo} using
     * either the LAN or the WAN address depending on the value of
     * {@link #useLanAddress}.
     * 
     * @return
     */
    public FiveTuple fiveTuple() {
        return new FiveTuple(getBoundFrom(), useLanAddress ? lanAddress()
                : wanAddress(), getProtocol());
    }
    
    /**
     * Specifies the priority of this proxy relative to similar proxies. A lower
     * number means a higher priority (i.e. -1 is higher priority than 0).
     */
    public int getPriority() {
        return priority;
    }

    public void setPriority(int priority) {
        this.priority = priority;
    }

    /**
     * Tracks ports to which this Proxy is limited.  If empty, the proxy is
     * assumed to support all ports.  If not empty, it only supports whatever
     * ports are listed.
     */
    public Set<Integer> getLimitedToPorts() {
        return limitedToPorts;
    }

    public void addLimitedToPort(int port) {
        limitedToPorts.add(port);
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((authToken == null) ? 0 : authToken.hashCode());
        result = prime * result
                + ((boundFrom == null) ? 0 : boundFrom.hashCode());
        result = prime * result + ((cert == null) ? 0 : cert.hashCode());
        result = prime * result + ((jid == null) ? 0 : jid.hashCode());
        result = prime * result + ((lanHost == null) ? 0 : lanHost.hashCode());
        result = prime * result + lanPort;
        result = prime * result + (isNatTraversed() ? 1231 : 1237);
        result = prime
                * result
                + ((pt == null) ? 0
                        : pt.hashCode());
        result = prime * result
                + ((protocol == null) ? 0 : protocol.hashCode());
        result = prime * result + ((type == null) ? 0 : type.hashCode());
        result = prime * result + ((wanHost == null) ? 0 : wanHost.hashCode());
        result = prime * result + wanPort;
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        ProxyInfo other = (ProxyInfo) obj;
        if (authToken == null) {
            if (other.authToken != null)
                return false;
        } else if (!authToken.equals(other.authToken))
            return false;
        if (boundFrom == null) {
            if (other.boundFrom != null)
                return false;
        } else if (!boundFrom.equals(other.boundFrom))
            return false;
        if (cert == null) {
            if (other.cert != null)
                return false;
        } else if (!cert.equals(other.cert))
            return false;
        if (jid == null) {
            if (other.jid != null)
                return false;
        } else if (!jid.equals(other.jid))
            return false;
        if (lanHost == null) {
            if (other.lanHost != null)
                return false;
        } else if (!lanHost.equals(other.lanHost))
            return false;
        if (lanPort != other.lanPort)
            return false;
        if (isNatTraversed() != other.isNatTraversed())
            return false;
        if (pt == null) {
            if (other.pt != null)
                return false;
        } else if (!pt.equals(other.pt))
            return false;
        if (protocol != other.protocol)
            return false;
        if (type != other.type)
            return false;
        if (wanHost == null) {
            if (other.wanHost != null)
                return false;
        } else if (!wanHost.equals(other.wanHost))
            return false;
        if (wanPort != other.wanPort)
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "ProxyInfo [jid=" + jid + ", type=" + type + ", natTraversed="
                + isNatTraversed() + ", wanHost=" + wanHost + ", wanPort="
                + wanPort + ", lanHost=" + lanHost + ", lanPort=" + lanPort
                + ", boundFrom=" + boundFrom + ", protocol=" + protocol
                + ", authToken=" + authToken + ", cert=" + cert
                + ", pt=" + pt + "]";
    }

}
