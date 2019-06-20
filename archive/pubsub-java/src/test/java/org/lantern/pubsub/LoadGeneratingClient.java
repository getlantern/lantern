package org.lantern.pubsub;

import java.util.Random;

/**
 * This client generates load for performance testing. Useful in conjunction
 * with the Go perfclient.
 */
public class LoadGeneratingClient extends BaseClient {
    private static final byte[] BODY = Client.utf8("this is the message body");
    private static final long REPORT_INTERVAL = 10000;
    private static final long CHECK_INTERVAL = 1000;
    private static final long TARGET_TPS = 100000;
    private static final long TARGET_DELTA = CHECK_INTERVAL * 1000 / TARGET_TPS;
    private static final Random random = new Random(System.currentTimeMillis());

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            System.err
                    .println("Please specify number of clients");
            System.exit(1);
        }

        int numClients = Integer.parseInt(args[0]);

        System.out.println("NumClients: " + numClients + "   Target Delta: "
                + TARGET_DELTA);

        Client client = newClient();
        long checkStart = System.currentTimeMillis();
        long reportStart = System.currentTimeMillis();
        for (long i = 0; i < Long.MAX_VALUE; i++) {
            client.publish(
                    Client.utf8("perfclient" + random.nextInt(numClients)),
                    BODY);
            if (i % CHECK_INTERVAL == 0 && i > 0) {
                long delta = System.currentTimeMillis() - checkStart;
                checkStart = System.currentTimeMillis();
                long delay = TARGET_DELTA - delta;
                if (delay > 0) {
                    System.out.println(delta + " : " + delay);
                    // Slow things down
                    Thread.sleep(delay);
                }
            }
            if (i % REPORT_INTERVAL == 0 && i > 0) {
                double delta = System.currentTimeMillis() - reportStart;
                System.out.println("Total: " + i + "    TPS: "
                        + (REPORT_INTERVAL * 1000.0 / delta));
                reportStart = System.currentTimeMillis();
            }
        }
    }
}
