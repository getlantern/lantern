package org.lantern;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.DefaultChannelFuture;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;

/**
 * a class that represents a round trip communication with 
 * callbacks to inspect results.  Throwing an exception 
 * during any of the callbacks will cause the test to 
 * fail.  If nothing is thrown, the result is assumed
 * to be a success.
 * 
 * the request and response are saved on the test 
 * for inspection or further use following the test 
 * if needed.
 */
public abstract class RoundTripTest {

    public ChannelFuture result;

     // these are captured by running the test for further inspection/use
    public HttpRequest request;
    public HttpResponse response;

    public RoundTripTest() {}

    /**
     * create and return the initial request that should be sent.
     */ 
    public abstract HttpRequest createRequest() throws Exception;

    /** 
     * perform any checks on the request, then create and return the response 
     * the channel is provided as a convenience, but it is not necessary to 
     * write the response to the channel only return it.
     */ 
    public abstract HttpResponse createResponse(HttpRequest request, Channel origin) throws Exception;

    /**
     * inspect the HttpResponse that was returned as result of the 
     * request.
     */
    public abstract void handleResponse(HttpResponse response) throws Exception;


    public int getTimeLimit() {return 2500;}

    /**
     * destroy any state associated with the test and prepare to re-run 
     */
    public void reset(Channel channel) {
        result = new DefaultChannelFuture(channel, true);
        request = null;
        response = null;
    }
}
