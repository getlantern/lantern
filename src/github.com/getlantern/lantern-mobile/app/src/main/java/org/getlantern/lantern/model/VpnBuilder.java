package org.getlantern.lantern.model;

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
import java.util.Map;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.android.vpn.Tun2Socks;
import org.getlantern.lantern.android.vpn.Tunio;


public class VpnBuilder extends VpnService {

    public static boolean USE_LANTERN_SOCKS = true;

    private static final String TAG = "VpnBuilder";
    private PendingIntent mConfigureIntent;

    private final static String sessionName = "LanternVpn";
    private final static String virtualNetMask = "255.255.255.0";
    private final static int VPN_MTU = 1500;

    private ParcelFileDescriptor mInterface;

    private final static Map<String, Integer> prefixLengths = new HashMap<String, Integer>();
    static
    {
        prefixLengths.put("10.0.0.0", 8);
        prefixLengths.put("172.16.0.0", 12);
        prefixLengths.put("192.168.0.0", 16);
        prefixLengths.put("169.254.1.0", 24);
    }

    public synchronized void configure() throws Exception {


        if (mInterface != null) {
            Log.i(TAG, "Using the previous interface");
            return;
        }

        String addressRange = getLocalHostLANRange();
        Log.d(TAG, "Address range is " + addressRange);
        String ipAddress = getNextIPV4Address(addressRange);
        String routerAddress = getNextIPV4Address(ipAddress);
        Log.d(TAG, "IP address is " + ipAddress);
        Log.d(TAG, "Router address is " + routerAddress);

        // Configure a builder while parsing the parameters.
        Builder builder = new Builder();
        builder.setMtu(VPN_MTU);
        builder.addRoute("0.0.0.0", 0);
        builder.addAddress(ipAddress, prefixLengths.get(addressRange));
        builder.addRoute(addressRange, prefixLengths.get(addressRange));
        builder.addDnsServer(routerAddress);

        // Close old VPN interface
        try {
            mInterface.close();
        } catch (Exception e) {
            // ignore
        }

        // Create a new interface using the builder and save the parameters.
        mInterface = builder.setSession(sessionName)
            .setConfigureIntent(mConfigureIntent)
            .establish();

        Log.i(TAG, "New interface: " + mInterface);

        if (this.USE_LANTERN_SOCKS) {
            Log.i(TAG, "Using tun2socks");

            Tun2Socks.Start(
                    mInterface,
                    VPN_MTU,
                    routerAddress,
                    virtualNetMask,
                    "127.0.0.1:" + String.valueOf(LanternConfig.SOCKS_PORT),
                    LanternConfig.UDPGW_SERVER,
                    true
            );
        } else {
            Log.i(TAG, "Using tunio");

            Tunio.Start(
                    mInterface,
                    VPN_MTU,
                    routerAddress,
                    virtualNetMask,
                    LanternConfig.UDPGW_SERVER);
        }

    }

    public void close() throws Exception {
        if (mInterface != null) {
            mInterface.close();
            mInterface = null;
        }
        if (this.USE_LANTERN_SOCKS) {
            Tun2Socks.Stop();
        } else {
            Tunio.Stop();
        }
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
    // we use a Hidden API here only available in Android 4.0 and above
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

    // getLocalHostLANRange iterates through the active network interfaces
    // to identify the first available private IP address range
    private static String getLocalHostLANRange() throws Exception {

        Map<String, Boolean> addressRanges = new HashMap<String, Boolean>();
        addressRanges.put("10.0.0.0", true);
        addressRanges.put("172.16.0.0", true);
        addressRanges.put("192.168.0.0", true);
        addressRanges.put("169.254.1.0", true);

        InetAddress candidateAddress = null;
        // Iterate all NICs (network interface cards)...
        for (Enumeration ifaces = NetworkInterface.getNetworkInterfaces(); ifaces.hasMoreElements();) {
            NetworkInterface iface = (NetworkInterface) ifaces.nextElement();
            // Iterate all IP addresses assigned to each card...
            // to mark off unavailable address ranges
            for (Enumeration inetAddrs = iface.getInetAddresses(); inetAddrs.hasMoreElements();) {
                InetAddress inetAddr = (InetAddress) inetAddrs.nextElement();
                String ipAddr = inetAddr.getHostAddress();
                if (InetAddressUtils.isIPv4Address(ipAddr) && !inetAddr.isLoopbackAddress()) {
                    if (ipAddr.startsWith("10.")) {
                        addressRanges.remove("10.0.0.0");
                    }
                    else if (
                            ipAddr.length() >= 6 &&
                            ipAddr.substring(0, 6).compareTo("172.16") >= 0 &&
                            ipAddr.substring(0, 6).compareTo("172.31") <= 0) {
                        addressRanges.remove("172.16.0.0");
                    }
                    else if (ipAddr.startsWith("192.168")) {
                        addressRanges.remove("192.168.0.0");
                    }
                }
            }
        }

        for (Map.Entry<String, Boolean> entry : addressRanges.entrySet()) {
            if (entry.getValue()) {
                return entry.getKey();
            }
        }

        throw new Exception("No available private address range");
    }
}
