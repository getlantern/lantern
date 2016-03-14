package org.lantern.pubsub;

import org.lantern.pubsub.Client;
import org.lantern.pubsub.Client.ClientConfig;

public class BaseClient {
    public static final String SERVER = "pubsub.lantern.io";
    public static final int PORT = 14443;
    public static final byte[] TOPIC = Client.utf8("topic");
    
    protected static Client newClient(String authenticationKey,
            byte[]... initialTopics) {
        ClientConfig cfg = new ClientConfig(SERVER, PORT);
        cfg.authenticationKey = authenticationKey;
        cfg.backoffBase = 100;
        cfg.maxBackoff = 15000;
        cfg.initialTopics = initialTopics;
        return new Client(cfg);
    }
}
