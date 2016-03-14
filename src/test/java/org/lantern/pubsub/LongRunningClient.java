package org.lantern.pubsub;

import org.lantern.pubsub.Client;
import org.lantern.pubsub.Message;

public class LongRunningClient extends BaseClient {
    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            System.err.println("Please specify an authentication key");
            System.exit(1);
        }

        Client client = newClient(args[0], TOPIC);
        while (true) {
            client.publish(TOPIC, BODY).send();
            System.err.println("Published");
            Message msg = client.read();
            System.err.println("Got: " + new String(msg.getBody()));
            System.err.println("Sleeping 2 minutes");
            Thread.sleep(2 * 60 * 1000);
        }
    }
}
