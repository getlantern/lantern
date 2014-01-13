package org.lantern;

public class FallbackProxy {

    private String ip;
    
    private int port;
    
    private String auth_token;
    
    private String protocol;

    public FallbackProxy() {}

    public FallbackProxy(final String ip, final int port) {
        this.ip = ip;
        this.port = port;
    }

    public String getIp() {
        return ip;
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }
    
    public String getAuth_token() {
        return auth_token;
    }
    
    public void setAuth_token(String auth_token) {
        this.auth_token = auth_token;
    }
    
    public String getProtocol() {
        return protocol;
    }
    
    public void setProtocol(String protocol) {
        this.protocol = protocol;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((auth_token == null) ? 0 : auth_token.hashCode());
        result = prime * result + ((ip == null) ? 0 : ip.hashCode());
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
        FallbackProxy other = (FallbackProxy) obj;
        if (auth_token == null) {
            if (other.auth_token != null)
                return false;
        } else if (!auth_token.equals(other.auth_token))
            return false;
        if (ip == null) {
            if (other.ip != null)
                return false;
        } else if (!ip.equals(other.ip))
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
        return "FallbackProxy [ip=" + ip + ", port=" + port + ", auth_token="
                + auth_token + ", protocol=" + protocol + "]";
        
    }
    
}
