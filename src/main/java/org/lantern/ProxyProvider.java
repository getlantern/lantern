package org.lantern;

import java.net.InetSocketAddress;

public interface ProxyProvider {

    InetSocketAddress getLaeProxy();

    InetSocketAddress getProxy();

}
