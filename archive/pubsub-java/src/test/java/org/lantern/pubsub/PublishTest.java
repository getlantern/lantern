package org.lantern.pubsub;

import java.util.concurrent.TimeUnit;

import org.junit.Test;

import static org.junit.Assert.*;

public class PublishTest extends BaseClient {
    private static final byte[] TEST_TOPIC = Client.utf8("Test Topic"); 
    private static final byte[] TEST_BODY = Client.utf8("Test Body");
    
    @Test
    public void testRoundTrip() throws Exception {
        Client client = newClient();
        client.subscribe(TEST_TOPIC);
        client.publish(TEST_TOPIC, TEST_BODY);
        Message msg = client.readTimeout(5, TimeUnit.SECONDS);
        assertArrayEquals("Wrong topic", TEST_TOPIC, msg.getTopic());
        assertArrayEquals("Wrong body", TEST_BODY, msg.getBody());
    }
}
