package org.lantern.util;

import java.io.IOException;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;

public class GatewayUtil {

    public static void openGateway() {
        if (SystemUtils.IS_OS_MAC_OSX) {
            try {
                Runtime.getRuntime().exec("open \"http://``\"");
            } catch (final IOException e) {
                e.printStackTrace();
            }
        }
    }
    
    public static String defaultGateway() throws IOException, InterruptedException {
        final Process gateway = Runtime.getRuntime().exec("netstat -nr | grep '^default' | awk '{ print $2 }'");
        System.err.println(gateway.waitFor());
        return IOUtils.toString(gateway.getInputStream());
    }

    public static void main(final String[] args) {
        try {
            System.out.println(defaultGateway());
        } catch (IOException e) {
            e.printStackTrace();
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        System.err.println("DONE");
    }
}
