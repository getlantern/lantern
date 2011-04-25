package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;

public interface Proxy {

    URI getPeerProxy();
    
    InetSocketAddress getProxy();
}
