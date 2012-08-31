package org.lantern;

import java.util.Queue;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.handler.codec.http.DefaultHttpChunk;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handles connections from the local proxy to external proxies, relaying
 * data back to the original channel to the browser.
 */
public class ChunkedProxyDownloader extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Channel browserToProxyChannel;

    private final Queue<HttpRequest> httpRequests;

    private final HttpRequest originalRequest;

    private final ChannelGroup channelGroup;

    /**
     * Creates a new chunked downloader.
     * 
     * @param request The HTTP request starting this download.
     * @param browserToProxyChannel The connection to the browser/client.
     * @param httpRequests All HTTP requests on this connection to the 
     * client/browser.
     */
    public ChunkedProxyDownloader(final HttpRequest request, 
        final Channel browserToProxyChannel,
        final Queue<HttpRequest> httpRequests, final ChannelGroup channelGroup){
        this.originalRequest = request;
        this.browserToProxyChannel = browserToProxyChannel;
        this.httpRequests = httpRequests;
        this.channelGroup = channelGroup;
    }
    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) throws Exception {
        final Channel ch = cse.getChannel();
        log.info("New channel opened: {}", ch);
        this.channelGroup.add(ch);
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) {
        final Object msg = e.getMessage();
        
        if (msg instanceof HttpChunk) {
            final HttpChunk chunk = (HttpChunk) msg;
            
            if (chunk.isLast()) {
                log.info("GOT LAST CHUNK FOR {}", this.originalRequest.getUri());
            }
            //log.info("Chunk size: {}", chunk.getContent().readableBytes());
            browserToProxyChannel.write(chunk);
        } else {
            log.info("Got message on outbound handler: {}", msg);
            // There should always be a one-to-one relationship between
            // requests and responses, so we want to pop a request off the
            // queue for every response we get in. This is only really
            // needed so we have all the appropriate request values for
            // making additional requests to handle 206 partial responses.
            final HttpRequest request = httpRequests.remove();
            //final ChannelBuffer msg = (ChannelBuffer) e.getMessage();
            //if (msg instanceof HttpResponse) {
            final HttpResponse response = (HttpResponse) msg;
            final int code = response.getStatus().getCode();
            if (code != 206) {
                if (code >= 500 && code < 600) {
                    log.warn("Server error response: {}",response.getHeaders());
                    browserToProxyChannel.write(response);
                    browserToProxyChannel.close();
                    return;
                }
                log.info("No 206. Writing whole response");
                browserToProxyChannel.write(response);
            } else {
                
                
                // We just grab this before queuing the request because
                // we're about to remove it.
                final String cr = 
                    response.getHeader(HttpHeaders.Names.CONTENT_RANGE);
                final long cl = parseFullContentLength(cr);
                
                if (isFirstChunk(cr)) {
                    // If this is the *first* partial response to this 
                    // request, we need to build a new HTTP response as if 
                    // it were a normal, non-partial 200 OK. We need to 
                    // make sure not to do this for *every* 206 response, 
                    // however.
                    response.setStatus(HttpResponseStatus.OK);
                    
                    log.info("Setting Content Length to: "+cl+" from "+cr);
                    
                    // We need to set the appropriate total content length 
                    // here. This should be the final value of the Content-Range
                    // as the Content-Length header is just the length of the
                    // content for this single response, not the full entity.
                    response.setHeader(HttpHeaders.Names.CONTENT_LENGTH, cl);
                    response.removeHeader(HttpHeaders.Names.CONTENT_RANGE);
                    browserToProxyChannel.write(response);
                } else {
                    // We need to grab the body of the partial response
                    // and return it as an HTTP chunk.
                    final HttpChunk chunk = 
                        new DefaultHttpChunk(response.getContent());
                    browserToProxyChannel.write(chunk);
                }
                
                // Spin up additional requests on a new thread.
                requestRange(request, cr, cl, ctx.getChannel());
            }
        }
    }
    

    private boolean isFirstChunk(final String contentRange) {
        return contentRange.trim().startsWith("bytes 0-");
    }

    private long parseFullContentLength(final String contentRange) {
        final String fullLength = 
            StringUtils.substringAfterLast(contentRange, "/");
        return Long.parseLong(fullLength);
    }

    private void requestRange(final HttpRequest request, 
        final String contentRange, final long fullContentLength, 
        final Channel channel) {
        log.info("Queuing request based on Content-Range: {}", contentRange);
        // Note we don't need to thread this since it's all asynchronous 
        // anyway.
        final String body = 
            StringUtils.substringAfter(contentRange, "bytes ");
        if (StringUtils.isBlank(body)) {
            log.error("Blank bytes body: "+contentRange);
            return;
        }
        //final long contentLength = HttpHeaders.getContentLength(response);
        final String startPlus = StringUtils.substringAfter(body, "-");
        final String startString = StringUtils.substringBefore(startPlus, "/");
        final long start = Long.parseLong(startString) + 1;
        
        // This means the last response provided the final range, so we don't
        // want to request another one.
        if (start == fullContentLength) {
            log.info("Received full length...not requesting new range");
            return;
        }
        final long end;
        if (fullContentLength - start > LanternConstants.CHUNK_SIZE) {
            end = start + LanternConstants.CHUNK_SIZE;
        } else {
            end = fullContentLength - 1;
        }
        request.setHeader(HttpHeaders.Names.RANGE, "bytes="+start+"-"+end);
        request.setHeader(LanternConstants.LANTERN_VERSION_HTTP_HEADER_NAME, 
            LanternConstants.LANTERN_VERSION_HTTP_HEADER_VALUE);
        writeRequest(request, channel);
    }
    
    /**
     * Helper method that ensures all written requests are properly recorded.
     * 
     * @param request The request.
     */
    private void writeRequest(final HttpRequest request, final Channel channel) {
        this.httpRequests.add(request);
        log.info("Writing request: {}", request);
        channel.write(request);
    }

    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        log.info("Channel to external proxy closed");
        ProxyUtils.closeOnFlush(browserToProxyChannel);
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on OUTBOUND channel", e.getCause());
        ProxyUtils.closeOnFlush(e.getChannel());
    }
}
