package org.lantern.proxy;

import org.littleshoot.util.FiveTuple.Protocol;

public class ProxyInfo {

    protected String address;
    protected int port;
    protected String localAddress;
    protected int localPort;
    protected String authToken;
    protected Protocol protocol;
    protected String cert;

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public String getLocalAddress() {
        return localAddress;
    }

    public void setLocalAddress(String localAddress) {
        this.localAddress = localAddress;
    }

    public int getLocalPort() {
        return localPort;
    }

    public void setLocalPort(int localPort) {
        this.localPort = localPort;
    }

    public String getAuthToken() {
        return authToken;
    }

    public void setAuthToken(String authToken) {
        this.authToken = authToken;
    }

    public Protocol getProtocol() {
        return protocol;
    }

    public void setProtocol(Protocol protocol) {
        this.protocol = protocol;
    }

    public String getCert() {
        return cert;
    }

    public void setCert(String cert) {
        this.cert = cert;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((address == null) ? 0 : address.hashCode());
        result = prime * result
                + ((authToken == null) ? 0 : authToken.hashCode());
        result = prime * result + ((cert == null) ? 0 : cert.hashCode());
        result = prime * result
                + ((localAddress == null) ? 0 : localAddress.hashCode());
        result = prime * result + localPort;
        result = prime * result + port;
        result = prime * result
                + ((protocol == null) ? 0 : protocol.hashCode());
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
        if (address == null) {
            if (other.address != null)
                return false;
        } else if (!address.equals(other.address))
            return false;
        if (authToken == null) {
            if (other.authToken != null)
                return false;
        } else if (!authToken.equals(other.authToken))
            return false;
        if (cert == null) {
            if (other.cert != null)
                return false;
        } else if (!cert.equals(other.cert))
            return false;
        if (localAddress == null) {
            if (other.localAddress != null)
                return false;
        } else if (!localAddress.equals(other.localAddress))
            return false;
        if (localPort != other.localPort)
            return false;
        if (port != other.port)
            return false;
        if (protocol == null) {
            if (other.protocol != null)
                return false;
        } else if (!protocol.equals(other.protocol))
            return false;
        return true;
    }

    @Override
    public String toString() {
        return String
                .format(
                        "%1$s [address=%2$s, port=%3$s, localAddress=%4$s, localPort=%5$s, authToken=%6$s, protocol=%7$s]",
                        getClass().getSimpleName(),
                        address, port,
                        localAddress, localPort,
                        authToken, protocol);
    }
}
