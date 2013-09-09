package org.lantern;

import java.io.FileInputStream;
import java.net.ServerSocket;

/**
 * This test demonstrates the issue seen described in <a href=
 * "http://stackoverflow.com/questions/16191236/tomcat-startup-fails-due-to-java-net-socketexception-invalid-argument-on-mac-o"
 * >this StackOverflow entry</a>.
 */
public class SelectBrokenOnOSX {
    public static void main(String[] args) throws Exception {
        // Use 1024 file descriptors. There'll already be some in use,
        // obviously, but this guarantees the problem will occur
        for (int i = 0; i < 1024; i++) {
            new FileInputStream("/dev/null");
        }

        System.out.println("Opening socket");
        ServerSocket socket = new ServerSocket(8080);
        socket.accept();
    }

}
