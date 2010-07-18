package org.mg.client;


/**
 * Launches a new HTTP proxy.
 */
public class Launcher {

    /**
     * Starts the proxy from the command line.
     * 
     * @param args Any command line arguments.
     */
    public static void main(final String... args) {
        final int defaultPort = 8080;
        int port;
        if (args.length > 0) {
            final String arg = args[0];
            try {
                port = Integer.parseInt(arg);
            } catch (final NumberFormatException e) {
                port = defaultPort;
            }
        } else {
            port = defaultPort;
        }
        
        System.out.println("About to start server on port: "+port);
        final HttpProxyServer server = new DefaultHttpProxyServer(port);
        server.start();
    }
}
