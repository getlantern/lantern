package org.getlantern.lantern.android.vpn;

import android.annotation.TargetApi;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.net.DatagramSocket;
import java.net.Socket;
import go.client.Client;

/**
 * Created by rev on 11/13/15.
 */


@TargetApi(Build.VERSION_CODES.HONEYCOMB_MR1)
public class Tunio
{
    public static interface IProtectSocket
    {
        boolean doVpnProtect(Socket socket);
        boolean doVpnProtect(DatagramSocket socket);
    };

    private static final String TAG = Tunio.class.getSimpleName();
    private static final boolean LOGD = true;

    private static ParcelFileDescriptor mVpnInterfaceFileDescriptor;
    private static int mVpnInterfaceMTU;
    private static String mVpnIpAddress;
    private static String mVpnNetMask;
    private static String mUdpgwServerAddress;

    public static void Start(
            ParcelFileDescriptor vpnInterfaceFileDescriptor,
            int vpnInterfaceMTU,
            String vpnIpAddress,
            String vpnNetMask,
            String udpgwServerAddress)
    {
        mVpnInterfaceFileDescriptor = vpnInterfaceFileDescriptor;
        mVpnInterfaceMTU = vpnInterfaceMTU;
        mVpnIpAddress = vpnIpAddress;
        mVpnNetMask = vpnNetMask;
        mUdpgwServerAddress = udpgwServerAddress;

        if (mVpnInterfaceFileDescriptor != null) {
            Client.ConfigureFD(
                    mVpnInterfaceFileDescriptor.detachFd(),
                    mVpnInterfaceMTU,
                    mVpnIpAddress,
                    mVpnNetMask,
                    mUdpgwServerAddress);
        }
    }

    public static void Stop()
    {
        try {
            Client.StopClientProxy();
        } catch (Exception e) {
            Log.d(TAG, "Got an exception trying to stop Lantern: " + e);
        }
    }

    public static void logTun2Socks(
            String level,
            String channel,
            String msg)
    {
        String logMsg = level + "(" + channel + "): " + msg;
        if (0 == level.compareTo("ERROR"))
        {
            Log.e(TAG, logMsg);
        }
        else
        {
            if (LOGD) Log.d(TAG, logMsg);
        }
    }

}
