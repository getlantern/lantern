package org.lantern;

import static org.junit.Assert.*;
import static org.mockito.Matchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.junit.Test;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.proxy.FallbackProxy;
import org.lantern.state.Model;
import org.lantern.util.DefaultHttpClientFactory;
import org.lantern.util.HttpClientFactory;

import com.google.common.eventbus.Subscribe;

public class S3ConfigFetcherTest {

    private final AtomicReference<MessageEvent> messageRef = 
            new AtomicReference<MessageEvent>();
    
    @Test
    public void testStopAndStart() throws Exception {
        final Model model = new Model();
        final S3ConfigFetcher fetcher = new S3ConfigFetcher(model);
        
        model.setS3Config(null);
        fetcher.init();
        fetcher.start();
        assertNotNull(model.getS3Config());
        
        
        model.setS3Config(null);
        fetcher.stop();
        assertNull(model.getS3Config());
        
        fetcher.init();
        fetcher.start();
        assertNotNull(model.getS3Config());
    }
    
    @Test
    public void testWithExceptions() throws Exception {
        Events.register(this);
        final Model model = new Model();
        final HttpClientFactory clientFactory = mock(HttpClientFactory.class);
        final HttpClient client = mock(HttpClient.class);
        when(client.execute(any(HttpGet.class))).thenThrow(new IOException());
        
        when(clientFactory.newDirectClient()).thenReturn(client);
        when(clientFactory.newProxiedClient()).thenReturn(client);
        final S3ConfigFetcher fetcher = new S3ConfigFetcher(model);
        
        assertEquals(1, model.getS3Config().getFallbacks().size());
        
        model.getS3Config().setFallbacks(Arrays.asList(new FallbackProxy()));
        
        assertNull(messageRef.get());
        fetcher.init();
        
        assertEquals(2, model.getS3Config().getFallbacks().size());
        
        Thread.sleep(200);
        
        // We want to make sure the message is not sent here, as a single 
        // failure to download shouldn't result in this message.
        assertNull(messageRef.get());
    }
    
    @Subscribe
    public void onMessage(final MessageEvent event) {
        messageRef.set(event);
    }

}
