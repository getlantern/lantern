package org.lantern.geoip;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.util.TreeMap;

import org.lantern.state.Location;
import org.littleshoot.util.BitUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 *
 * @author leah
 *
 */
@Singleton
public class GeoIpLookupService {
    private static final Logger LOG = LoggerFactory
            .getLogger(GeoIpLookupService.class);

    private TreeMap<Long, Location> table;

    private volatile boolean dataLoaded = false;

    public GeoIpLookupService() {
        this(true);
    }

    public GeoIpLookupService(boolean threadDataLoading) {
        if (threadDataLoading) {
            threadLoadData();
        } else {
            loadData();
        }
    }

    public void threadLoadData() {

        Runnable runnable = new Runnable() {
            @Override
            public void run() {
                loadData();
            }
        };
        Thread thread = new Thread(runnable);
        thread.setDaemon(true);
        thread.start();
    }

    private Location getLocation(byte[] bytes) {
        // we might have to wait here until our table is set up.
        while (!dataLoaded) {
            try {
                synchronized(this) {
                    wait(100);
                }
            } catch (InterruptedException e) {
            }
        }
        long address = BitUtils.byteArrayToInteger(bytes);
        if (address < 0) {
            address = (1 << 32) - address;
        }
        return table.floorEntry(address).getValue();
    }

    public Location getLocation(InetAddress ip) {
        return getLocation(ip.getAddress());
    }

    public Location getLocation(String ip) {
        byte[] bytes = new byte[4];
        String[] parts = ip.split("\\.");

        for (int i = 0; i < 4; i++) {
            bytes[i] = (byte) Integer.parseInt(parts[i]);
        }

        return getLocation(bytes);
    }

    private synchronized void loadData() {
        if (table != null)
            return;
        table = new TreeMap<Long, Location>();

        GeoIpCompressor compressor = new GeoIpCompressor();
        InputStream inStream = GeoIpLookupService.class
                .getResourceAsStream("geoip.db");

        if (inStream == null) {
            LOG.error("Failed to load geoip.db.  All geo ip lookups will fail.");
            dataLoaded = true;
            return;
        }
        try {
            compressor.readCompressedData(inStream);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        // convert
        long startIp = 0;
        for (int i = 0; i < compressor.ipRangeList.size(); ++i) {
            int range = compressor.ipRangeList.get(i);
            int pixelId = compressor.pixelIdList.get(i);
            Location location = new Location();
            int countryId = compressor.pixelIdToCountry.get(pixelId);
            String countryCode = compressor.countryIdToCountry
                    .get(countryId);
            location.setCountry(countryCode);
            int quantized = compressor.pixelIdToQuantizedLatLon
                    .get(pixelId);
            location.setLat(compressor.getLatFromQuantized(quantized));
            location.setLon(compressor.getLonFromQuantized(quantized));
            table.put(startIp, location);
            startIp += range;
        }

        dataLoaded = true;
        synchronized(this) {
            this.notify();
        }
    }

}
