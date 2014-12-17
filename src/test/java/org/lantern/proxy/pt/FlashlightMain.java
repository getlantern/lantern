package org.lantern.proxy.pt;

import java.net.InetSocketAddress;

import org.lantern.S3Config;

/**
 * <p>
 * This simple program runs a LittleProxy which uses a flashlight instance.
 * After running this program, you can do this:
 * </p>
 * 
 * <pre>
 * curl -x 127.0.0.1:8080 https://www.google.com/humans.txt
 * </pre>
 */
public class FlashlightMain extends ChainedMain {
    private static final int FLASHLIGHT_CLIENT_PORT = 8081;

    private InetSocketAddress clientAddress;

    public static void main(String[] args) throws Exception {
        new FlashlightMain().run();
    }

    public void run() throws Exception {
        // Start LittleProxy servers
        super.run();

        InetSocketAddress getModeAddress = new InetSocketAddress("localhost",
                FLASHLIGHT_CLIENT_PORT);

        // Client
        final FlashlightProxy proxy = new FlashlightProxy("default.peer.getiantem.org", 1,
                new FlashlightMasquerade(S3Config.DEFAULT_HOSTS_TO_CERTS),
                S3Config.DEFAULT_FLASHLIGHT_CLOUDCONFIG,
                S3Config.DEFAULT_FLASHLIGHT_CLOUDCONFIG_CA);
        
        
        Flashlight client = new Flashlight(proxy.getPt());
        this.clientAddress = client.startClient(getModeAddress, null);
    }

    @Override
    protected int getUpstreamPort() {
        return this.clientAddress.getPort();
    }

    @Override
    protected boolean requiresEncryption() {
        return false;
    }
}
