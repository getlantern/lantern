package org.lantern;

public class FallbackProxy {

    private String base64PublicKey = "";
    
    private String ip;
    
    private int port;

    
    public FallbackProxy() {}

    public FallbackProxy(final String ip, final int port) {
        this.ip = ip;
        this.port = port;
    }

    public String getBase64PublicKey() {
        return base64PublicKey;
    }

    public void setBase64PublicKey(String base64PublicKey) {
        this.base64PublicKey = base64PublicKey;
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

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((base64PublicKey == null) ? 0 : base64PublicKey.hashCode());
        result = prime * result + ((ip == null) ? 0 : ip.hashCode());
        result = prime * result + port;
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
        if (base64PublicKey == null) {
            if (other.base64PublicKey != null)
                return false;
        } else if (!base64PublicKey.equals(other.base64PublicKey))
            return false;
        if (ip == null) {
            if (other.ip != null)
                return false;
        } else if (!ip.equals(other.ip))
            return false;
        if (port != other.port)
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "FallbackProxy [base64PublicKey=" + base64PublicKey + ", ip="
                + ip + ", port=" + port + "]";
    }
}
