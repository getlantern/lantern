package org.lantern;

import java.util.concurrent.Executors;

import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelHandler;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import static org.junit.Assert.*;
import static org.lantern.TestingUtils.*;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


/**  
 * This is an abstract base class for helper classes that 
 * mock out a particualr type of lantern peer connection
 * and simulated lantern "client" pipeline
 * 
 * It provides support for running the RountTripTest class:
 *
 *
 * RoundTripTest rt = new RoundTripTest() {        
 *     @Override
 *     public HttpRequest createRequest() throws Exception {
 *       return createPostRequest("http://www.example.com/");
 *     }
 *
 *     @Override
 *     public HttpResponse createResponse(HttpRequest request, Channel origin) throws Exception {
 *        HttResponse response = createResponse("FOO", origin.getConfig().getBufferFactory());
 *        ...
 *        return response;
 *     }
 *
 *     @Override
 *     public void handleResponse(HttpResponse response) throws Exception {
 *         ChannelBuffer body = response.getContent();
 *        ...
 *     }
 * };
 *
 * MockConnection conn = new MockXYZConnection(); 
 * try {
 *     conn.runTest(rt);
 *     ...
 * }
 * finally {
 *     conn.teardown();    
 * }
 *
 *
 */

abstract class MockConnection {
    private final Logger log = LoggerFactory.getLogger(getClass());
 
    RoundTripTest currentTest;
    final ClientBootstrap clientBootstrap;

    public MockConnection()  {
        final ChannelFactory channelFactory = new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool()
        );
        clientBootstrap = new ClientBootstrap(channelFactory);
        
        final MockConnection thisConnection = this;
        clientBootstrap.setPipelineFactory(new ChannelPipelineFactory() {
            @Override
            public ChannelPipeline getPipeline() {
                ChannelPipeline pipeline = Channels.pipeline();
                pipeline.addLast("decoder", new HttpResponseDecoder());
                pipeline.addLast("encoder", new HttpRequestEncoder());
                pipeline.addLast("handler", new ClientTestHandler(thisConnection));
                return pipeline;
            }
        });
    }
    
    /** 
     * return an HttpRequest object doctored so that it will connect 
     * to the desired peer type 
     */
    public abstract HttpRequest createBaseRequest(String hostname);
    public abstract Channel connect() throws Exception;
    public abstract void teardown() throws Exception;    
    
    public void runTest(RoundTripTest test) throws Exception {
        
        currentTest = test;
        Channel proxyChannel = connect();

        test.reset(proxyChannel);
         
        HttpRequest req = test.createRequest();
        test.request = req;
        Channels.write(proxyChannel, req);
        
        test.result.await(test.getTimeLimit());
        if (!test.result.isSuccess()) {
            Throwable cause = test.result.getCause();
            if (cause != null) {
                cause.printStackTrace();
            }
        }

        assertTrue(test.result.isSuccess()); 
    }

    RoundTripTest getCurrentTest() {
        return currentTest;
    }
     

    /* this class represents how the fake "trusted" peer behaves */
    class FakePeerHandler extends SimpleChannelHandler {
        MockConnection connection;

        public FakePeerHandler(MockConnection connection) {
            this.connection = connection;
        }

        @Override
        public void messageReceived(ChannelHandlerContext ctx, MessageEvent evt) {
            RoundTripTest test = connection.getCurrentTest();

            try {
                HttpRequest req = (HttpRequest) evt.getMessage();
                Channel chan = ctx.getChannel();
                HttpResponse response = test.createResponse(req, chan);
                chan.write(response);
                super.messageReceived(ctx, evt);
            }
            catch (Throwable t) {
                test.result.setFailure(t);
            }
        }
    }

    class ClientTestHandler extends SimpleChannelHandler {
        
        MockConnection connection; 
        
        public ClientTestHandler(MockConnection connection) {
            super(); 
            this.connection = connection;
        }
        @Override
        public void handleUpstream(ChannelHandlerContext ctx, ChannelEvent evt) {
            
            RoundTripTest test = connection.getCurrentTest();
            try {
                if (evt instanceof MessageEvent) {
                    MessageEvent me = (MessageEvent) evt;
                    HttpResponse res = (HttpResponse) me.getMessage();
                    test.response = res;
                    test.handleResponse(res);
                    super.handleUpstream(ctx, evt);
                    test.result.setSuccess(); // round trip complete, no execeptions 
                }
                else {
                    super.handleUpstream(ctx, evt);
                }
            }
            catch (Throwable t) {
                test.result.setFailure(t);
            }
        }
    }
}