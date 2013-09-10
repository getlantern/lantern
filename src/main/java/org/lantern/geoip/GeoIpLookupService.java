package org.lantern.geoip;

import it.unimi.dsi.fastutil.ints.IntArrayList;
import it.unimi.dsi.fastutil.ints.IntList;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.apache.commons.io.IOUtils;
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

    private IntList lowerRanges;
    private IntList upperRanges;
    private List<GeoData> geoDataByIpRange;

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
        Thread thread = new Thread(runnable, "Geo-IP-Loading-Thread");
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
        int address = BitUtils.byteArrayToInteger(bytes);
        GeoData data;
        if (address > 0) {
            int insertionPoint = Collections.binarySearch(lowerRanges, address);
            if (insertionPoint < 0) {
                insertionPoint = -insertionPoint - 2;
            }
            data = geoDataByIpRange.get(insertionPoint);
        } else {
            address = (1 << 31) + address;
            int insertionPoint = Collections.binarySearch(upperRanges, address);
            if (insertionPoint < 0) {
                insertionPoint = -insertionPoint-2;
            }
            data = geoDataByIpRange.get(insertionPoint + lowerRanges.size());
        }
        return data;
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
        if (lowerRanges != null)
            return;

        lowerRanges = new IntArrayList();
        upperRanges = new IntArrayList();

        try {
            loadDataInternal();
        } finally {
            synchronized(this) {
                this.notifyAll();
            }
        }
    }

    private void loadDataInternal() {
        final GeoIpCompressor compressor = new GeoIpCompressor();
        
        InputStream inStream = null;
        try {
            inStream = GeoIpLookupService.class.getResourceAsStream("geoip.db");

            if (inStream == null) {
                LOG.error("Failed to load geoip.db...loading local file.");
                final File local = new File("src/main/resources/org/lantern/geoip/geoip.db");
                inStream = new FileInputStream(local);
                dataLoaded = true;
            }
    
            inStream = new BufferedInputStream(inStream);
    
            try {
                compressor.readCompressedData(inStream);
            } catch (IOException e) {
                throw new RuntimeException(e);
            } 
        } catch (final FileNotFoundException e) {
            LOG.error("Could not find local geoip.db?", e);
        } finally {
            IOUtils.closeQuietly(inStream);
        }

        // convert to searchable form

        List<GeoData> geoDataByPixelId = new ArrayList<GeoData>();
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
            geoDataByPixelId.add(GeoData);
        }

        // we're done with this data, so let's allow it to be garbage-collected
        compressor.pixelIdToCountry = null;
        compressor.pixelIdToQuantizedLatLon = null;

        long startIp = 0;
        final int size = compressor.ipRangeList.size();
        geoDataByIpRange = new ArrayList<GeoData>(size);
        for (int i = 0; i < size; ++i) {
            int range = compressor.ipRangeList.get(i);
            int pixelId = compressor.pixelIdList.get(i);
            final GeoData GeoData = geoDataByPixelId.get(pixelId);
            if (startIp < (1L<<31)) {
                lowerRanges.add((int)startIp);
            } else {
                upperRanges.add((int)(startIp - (1L<<31)));
            }
            geoDataByIpRange.add(GeoData);
            startIp += range;
        }

        dataLoaded = true;

    }

}
