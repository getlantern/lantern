package org.lantern;

import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.ServerSocket;
import java.net.Socket;

/**
 * <p>
 * This test demonstrates the issue seen described in <a href=
 * "http://stackoverflow.com/questions/16191236/tomcat-startup-fails-due-to-java-net-socketexception-invalid-argument-on-mac-o"
 * >this StackOverflow entry</a>.
 * </p>
 * 
 * <p>
 * This test fails when running with Oracle Java 7 on OS X 10.8.4. It succeeds
 * when running on the Apple supplied Java 6 on OS X 10.8.4.
 * </p>
 */
public class SelectBrokenOnOSX {
    public static void main(String[] args) throws Exception {
        final ServerSocket serverSocket = new ServerSocket(8000);

        new Thread() {
            @Override
            public void run() {
                try {
                    Socket socket = serverSocket.accept();
                    try {
                        OutputStream out = socket.getOutputStream();
                        try {
                            out.write("I'm here".getBytes());
                        } finally {
                            out.close();
                        }
                    } finally {
                        socket.close();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }.start();

        // Use 1024 file descriptors. There'll already be some in use,
        // obviously, but this guarantees the problem will occur
        for (int i = 0; i < 1024; i++) {
            new FileInputStream("/dev/null");
        }

        // This won't work unles you comment out the setSoTimeout() call
        Socket socket = new Socket("127.0.0.1", 8000);
        socket.setSoTimeout(4000);
        OutputStream out = socket.getOutputStream();
        out.write("Hello".getBytes());
        InputStream in = socket.getInputStream();
        int b;
        while ((b = in.read()) != -1) {
            System.out.print((char) b);
        }
        System.out.println("");
        out.close();
        in.close();
        socket.close();

        System.out.println("done");
    }
}
