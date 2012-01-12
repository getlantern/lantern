function FindProxyForURL(url, host) {
    if( host == "localhost" ||
  	host == "127.0.0.1") {
        return "DIRECT";
    }

    // If it's not localhost, try to use the proxy and go 
    // direct if there's a problem.
    return "PROXY 127.0.0.1:8787; DIRECT";
}
