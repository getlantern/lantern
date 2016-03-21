package org.getlantern.lantern.vpn;

import android.annotation.SuppressLint;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.annotation.TargetApi;
import android.util.Log;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.ParcelFileDescriptor;

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

import org.getlantern.lantern.activity.LanternMainActivity;
import org.getlantern.lantern.R;

import org.getlantern.lantern.android.vpn.Tun2Socks;

/**
 * <p>This code is largely based on Shadowsocks code from
 * <a href="https://github.com/andforce/SmartZPN/tree/master/app/src/main/java/org/zarroboogs/smartzpn">here</a>.</p>
 *
 * <p>The tun2socks code came from
 * <a href="https://github.com/ambrop72/badvpn/tree/master/tun2socks">here</a>.</p>
 */
@TargetApi(Build.VERSION_CODES.ICE_CREAM_SANDWICH)
public class VpnBuilder extends VpnService {

    private static final String TAG = "VpnBuilder";
    protected Thread vpnThread;
    private final static String mSessionName = "LanternVpn";
    private final static String mNetMask = "255.255.255.0";
    private final static String mVirtualIP = "26.25.0.0";
    private final static int VPN_MTU = 1500;

    private ArrayList<IPAddress> IpList = new ArrayList<IPAddress>();
    private ArrayList<IPAddress> DnsList = new ArrayList<IPAddress>();

    private ParcelFileDescriptor mInterface;

    public VpnBuilder() {
        IpList.add(new IPAddress("26.26.26.2", 32));
        DnsList.add(new IPAddress("114.114.114.114"));
        DnsList.add(new IPAddress("8.8.8.8"));
    }

    public void createBuilder() {

        // Set the locale to English
        // since the VpnBuilder encounters
        // issues with non-English numerals
        // See https://code.google.com/p/android/issues/detail?id=61096
        Locale.setDefault(new Locale("en"));

        // Configure a builder while parsing the parameters.
        Builder builder = new Builder();
        builder.setMtu(VPN_MTU);

        IPAddress ipAddress = IpList.get(0);
        builder.addAddress(ipAddress.Address, ipAddress.PrefixLength);
        Log.d(TAG, String.format("VpnBuilder addAddress: %s/%d\n", ipAddress.Address, ipAddress.PrefixLength));

        for (IPAddress dns : DnsList) {
            builder.addDnsServer(dns.Address);
        }

        builder.addRoute(mVirtualIP, 16);
        for (String routeAddress : getResources().getStringArray(R.array.bypass_private_route)) {
            String[] addr = routeAddress.split("/");
            builder.addRoute(addr[0], Integer.parseInt(addr[1]));
        }

        Intent intent = new Intent(this, LanternMainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, 0);
        builder.setConfigureIntent(pendingIntent);

        builder.setSession(mSessionName);

        // Create a new interface using the builder and save the parameters.
        mInterface = builder.establish();
        Log.i(TAG, "New interface: " + mInterface);
    }

    @TargetApi(Build.VERSION_CODES.ICE_CREAM_SANDWICH)
    public synchronized void configure(final String socksAddr) throws Exception {

        vpnThread = new Thread() {
            public void run() {

                Locale defaultLocale = Locale.getDefault();

                createBuilder();

                // revert back to the user's default locale
                Locale.setDefault(defaultLocale);

                String udpgwAddr = "127.0.0.1:7300";

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
        vpnThread.start();
    }

    public void close() throws Exception {
        if (mInterface != null) {
            mInterface.close();
            mInterface = null;
        }
        Tun2Socks.Stop();
        if (vpnThread != null) {
            vpnThread.interrupt();
        }
        vpnThread = null;
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

        Log.d(TAG, "Dns addresses found: " + addresses);
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

    public class IPAddress {
        public final String Address;
        public final int PrefixLength;

        public IPAddress(String address, int prefixLength) {
            this.Address = address;
            this.PrefixLength = prefixLength;
        }

        public IPAddress(String ipAddresString) {
            String[] arrStrings = ipAddresString.split("/");
            String address = arrStrings[0];
            int prefixLength = 32;
            if (arrStrings.length > 1) {
                prefixLength = Integer.parseInt(arrStrings[1]);
            }
            this.Address = address;
            this.PrefixLength = prefixLength;
        }

        @SuppressLint("DefaultLocale")
        @Override
        public String toString() {
            return String.format("%s/%d", Address, PrefixLength);
        }

        @Override
        public boolean equals(Object o) {
            if (o == null) {
                return false;
            } else {
                return this.toString().equals(o.toString());
            }
        }
    }

}
