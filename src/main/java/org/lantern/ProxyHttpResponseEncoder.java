package org.lantern;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseEncoder;
import org.littleshoot.proxy.ProxyHttpResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP response encoder for the proxy.
 */
public class ProxyHttpResponseEncoder extends HttpResponseEncoder {

    private final Logger log = LoggerFactory.getLogger(getClass());

    
    @Override
    protected Object encode(final ChannelHandlerContext ctx, 
        final Channel channel, final Object msg) throws Exception {
        if (msg instanceof ProxyHttpResponse) {
            log.info("Processing proxy response!!");
            final ProxyHttpResponse proxyResponse = (ProxyHttpResponse) msg;
            
            // We need the original request and response objects to adequately
            // follow the HTTP caching rules.
            final HttpRequest httpRequest = proxyResponse.getHttpRequest();
            final HttpResponse httpResponse = proxyResponse.getHttpResponse();
            
            final int code = httpResponse.getStatus().getCode();
            if (code != 200) {
                log.info("Got a non-200 response code: " + code);
                log.info("Request was: {} ", httpRequest);
                log.info("Response: {}", httpResponse);
            }
            
            // The actual response is either a chunk or a "normal" response.
            final Object response = proxyResponse.getResponse();
            
            final ChannelBuffer encoded = 
                (ChannelBuffer) super.encode(ctx, channel, response);
            return encoded;
        } else if (msg instanceof HttpResponse) {
            final ChannelBuffer encoded = 
                (ChannelBuffer) super.encode(ctx, channel, msg);
            return encoded;
        } else if (msg instanceof HttpChunk) {
            final ChannelBuffer encoded = 
                (ChannelBuffer) super.encode(ctx, channel, msg);
            return encoded;
        }
        log.info("Returning raw message object: {}", msg);
        return msg;
    }
}
