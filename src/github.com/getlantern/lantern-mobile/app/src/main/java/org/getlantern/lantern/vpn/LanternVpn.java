package org.getlantern.lantern.vpn;

import android.content.Context;
import android.util.Log;

import java.net.InetAddress;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.io.File;
import java.util.Map;
import java.util.HashMap;

import org.getlantern.lantern.model.UI;
import org.getlantern.lantern.sdk.Lantern;

// LanternVpn is a subclass of the SDK class Lantern
// it instantiates Lantern to run in full-device VPN mode
// along with a few customizations/extensions
public class LanternVpn extends Lantern {

    private static final String TAG = "LanternVpn";
    public static UI LanternUI;

    private Service service;

    public LanternVpn(Service service) {
        super(service.getApplicationContext(), "", true);
        // start Lantern in VPN mode
        this.service = service;
    }

    @Override
    public void AfterStart(String latestVersion) {
        super.AfterStart(latestVersion);
        // we pass the version number to setVersionNum which
        // populates the version string that appears at the bottom
        // of the side menu
        if (LanternUI != null) {
            LanternUI.setVersionNum(latestVersion);
        }
    }


    @Override
    public String GetDnsServer() {
        try {
            return service.getDnsResolver(service);
        } catch (Exception e) {
            return super.GetDnsServer();
        } 
    }

    // Protect is used to exclude a socket specified by fileDescriptor
    // from the VPN connection. Once protected, the underlying connection
    // is bound to the VPN device and won't be forwarded
    @Override
    public void Protect(long fileDescriptor) throws Exception {
        if (!this.service.protect((int) fileDescriptor)) {
            throw new Exception("protect socket failed");
        }
    }  

    // Notice is used to signal messages from Lantern
    // if fatal is true, Lantern encountered a fatal error
    // and we should shutdown
    @Override
    public void Notice(String message, boolean fatal) {
        Log.d(TAG, "Received a new message from Lantern: " + message);
        if (fatal) {
            Log.d(TAG, "Received fatal error.. Shutting down.");
            try { 
                // if we receive a fatal notice from Lantern
                // then we shut down the VPN interface
                // and close Tun2Socks
                //this.service.stop(false);
                //this.service.UI.handleFatalError();

            } catch (Exception e) {

            }
        }
    }

}
 
