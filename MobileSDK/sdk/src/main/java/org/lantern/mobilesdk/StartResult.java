package org.lantern.mobilesdk;

public class StartResult {
    private String HTTPAddr;
    private String SOCKS5Addr;

    public StartResult(String HTTPAddr, String SOCKS5Addr) {
        this.HTTPAddr = HTTPAddr;
        this.SOCKS5Addr = SOCKS5Addr;
    }

    public String getHTTPAddr() {
        return HTTPAddr;
    }

    public String getSOCKS5Addr() {
        return SOCKS5Addr;
    }
}
