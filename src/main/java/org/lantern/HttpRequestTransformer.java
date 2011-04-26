package org.lantern;

import java.net.InetSocketAddress;

import org.jboss.netty.handler.codec.http.HttpRequest;

public interface HttpRequestTransformer {

    void transform(HttpRequest request, InetSocketAddress proxyAddress);

}
