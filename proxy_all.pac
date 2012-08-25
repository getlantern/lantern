function FindProxyForURL(url, host) {
    if( host == "localhost" ||
        host == "127.0.0.1") {
        return "DIRECT";
    }
    return "PROXY 127.0.0.1:8787; DIRECT";
}
