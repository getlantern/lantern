package org.lantern.geoip;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;
import java.util.TreeMap;

import org.lantern.GeoData;
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

    private TreeMap<Long, GeoData> table;

    private volatile boolean dataLoaded = false;

    public GeoIpLookupService() {
        this(true);
    }

    public GeoIpLookupService(boolean loadImmediately) {
        if (loadImmediately) {
            threadLoadData();
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

    private GeoData getGeoData(byte[] bytes) {
        loadData();

        synchronized (this) {
            while (!dataLoaded) {
                try {
                    wait();
                } catch (InterruptedException e) {
                    //fall through
                }
            }
        }
        long address = BitUtils.byteArrayToInteger(bytes);
        if (address < 0) {
            address = (1L << 32) + address;
        }
        return table.floorEntry(address).getValue();
    }

    public GeoData getGeoData(InetAddress ip) {
        return getGeoData(ip.getAddress());
    }

    public GeoData getGeoData(String ip) {
        byte[] bytes = new byte[4];
        String[] parts = ip.split("\\.");

        for (int i = 0; i < 4; i++) {
            bytes[i] = (byte) Integer.parseInt(parts[i]);
        }

        return getGeoData(bytes);
    }

    private synchronized void loadData() {
        if (table != null)
            return;
        table = new TreeMap<Long, GeoData>();

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
        // convert to searchable form

        List<GeoData> GeoDatas = new ArrayList<GeoData>();
        for (int i = 0; i < compressor.pixelIdToCountry.size(); ++i) {
            GeoData GeoData = new GeoData();
            int countryId = compressor.pixelIdToCountry.get(i);
            String countryCode = compressor.countryIdToCountry
                    .get(countryId);
            GeoData.setCountrycode(countryCode);
            int quantized = compressor.pixelIdToQuantizedLatLon
                    .get(i);
            GeoData.setLatitude(compressor.getLatFromQuantized(quantized));
            GeoData.setLongitude(compressor.getLonFromQuantized(quantized));
            GeoDatas.add(GeoData);
        }

        long startIp = 0;
        for (int i = 0; i < compressor.ipRangeList.size(); ++i) {
            int range = compressor.ipRangeList.get(i);
            int pixelId = compressor.pixelIdList.get(i);
            GeoData GeoData = GeoDatas.get(pixelId);
            table.put(startIp, GeoData);
            startIp += range;
        }

        dataLoaded = true;
        synchronized(this) {
            this.notifyAll();
        }
    }

}
