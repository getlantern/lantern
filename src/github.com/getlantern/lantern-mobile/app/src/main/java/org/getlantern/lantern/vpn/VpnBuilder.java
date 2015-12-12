package org.getlantern.lantern.vpn;

import android.app.PendingIntent;
import android.content.Context;
import android.annotation.TargetApi;
import android.util.Log;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;

import org.apache.http.conn.util.InetAddressUtils;

import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashMap;
import java.net.InetAddress;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.getlantern.lantern.android.vpn.Tun2Socks;

public class VpnBuilder extends VpnService {

    private static final String TAG = "VpnBuilder";
    private PendingIntent mConfigureIntent;
    private Thread mThread;

    private final static String mSessionName = "LanternVpn";
    private final static String mVirtualIP = "10.0.0.2";
    private final static String mGateway = "10.0.0.1";
    private final static String mNetMask = "255.255.255.0";
    private final static int VPN_MTU = 1500;

    private ParcelFileDescriptor mInterface;

    @Override
    public void onCreate() {
        super.onCreate();
        // Set the locale to English
        // since the VpnBuilder encounters
        // issues with non-English numerals
        Locale.setDefault(new Locale("en"));
    }

    public void createBuilder() {
        // Configure a builder while parsing the parameters.
        Builder builder = new Builder();
        builder.setMtu(VPN_MTU);
        builder.addRoute("0.0.0.0", 0);
        builder.addAddress(mGateway, 28);
        builder.addDnsServer(mVirtualIP);

        // Close old VPN interface
        try {
            close();
        } catch (Exception e) {
            // ignore
        }

        // Create a new interface using the builder and save the parameters.
        mInterface = builder.setSession(mSessionName)
            .setConfigureIntent(mConfigureIntent)
            .establish();

        Log.i(TAG, "New interface: " + mInterface);
    }

    @TargetApi(Build.VERSION_CODES.ICE_CREAM_SANDWICH)
    public synchronized void configure(final Map settings) throws Exception {

        if (mInterface != null) {
            Log.i(TAG, "Using the previous interface");
            return;
        }

        mThread = new Thread() {
            public void run() {
                createBuilder();
                String socksAddr = "127.0.0.1:9131";
                String udpgwAddr = "127.0.0.1:7131";
                if (settings != null) {
                    socksAddr = (String)settings.get("socksaddr");
                    udpgwAddr = (String)settings.get("udpgwaddr");
                }
                Tun2Socks.Start(
                        mInterface,
                        VPN_MTU,
                        mVirtualIP,
                        mNetMask,
                        socksAddr,
                        udpgwAddr,
                        true
                        );  
            }
        };
        mThread.start();
    }

    public void close() throws Exception {
        if (mInterface != null) {
            mInterface.close();
            mInterface = null;
        }
        Tun2Socks.Stop();
        if (mThread != null) {
            mThread.interrupt();
        }
        mThread = null;
    }

    public void restart(Map settings) throws Exception {
        close();
        Thread.sleep(3000);
        configure(settings);
    }

    public static String getDnsResolver(Context context)
            throws Exception {
        Collection<InetAddress> dnsResolvers = getDnsResolvers(context);
        if (dnsResolvers.isEmpty()) {
            throw new Exception("Couldn't find an active DNS resolver");
        }
        String dnsResolver = dnsResolvers.iterator().next().toString();
        if (dnsResolver.startsWith("/")) {
            dnsResolver = dnsResolver.substring(1);
        }
        return dnsResolver;
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    private static Collection<InetAddress> getDnsResolvers(Context context)
            throws Exception {
        ArrayList<InetAddress> addresses = new ArrayList<InetAddress>();
        ConnectivityManager connectivityManager =
            (ConnectivityManager)context.getSystemService(Context.CONNECTIVITY_SERVICE);
        Class<?> LinkPropertiesClass = Class.forName("android.net.LinkProperties");
        Method getActiveLinkPropertiesMethod = ConnectivityManager.class.getMethod("getActiveLinkProperties", new Class []{});
        Object linkProperties = getActiveLinkPropertiesMethod.invoke(connectivityManager);
        if (linkProperties != null) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                Method getDnsesMethod = LinkPropertiesClass.getMethod("getDnses", new Class []{});
                Collection<?> dnses = (Collection<?>)getDnsesMethod.invoke(linkProperties);
                for (Object dns : dnses) {
                    addresses.add((InetAddress)dns);
                }
            } else {
                for (InetAddress dns : ((LinkProperties)linkProperties).getDnsServers()) {
                    addresses.add(dns);
                }
            }
        }
        return addresses;
    }

    public static String getNextIPV4Address(String ip) {
        String[] nums = ip.split("\\.");
        int i = (Integer.parseInt(nums[0]) << 24 | Integer.parseInt(nums[2]) << 8
                |  Integer.parseInt(nums[1]) << 16 | Integer.parseInt(nums[3])) + 1;

        // If you wish to skip over .255 addresses.
        if ((byte) i == -1) i++;

        return String.format("%d.%d.%d.%d", i >>> 24 & 0xFF, i >> 16 & 0xFF,
                i >>   8 & 0xFF, i >>  0 & 0xFF);
    }

}
