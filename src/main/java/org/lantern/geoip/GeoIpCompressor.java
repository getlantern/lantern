package org.lantern.geoip;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.collections.Bag;
import org.apache.commons.collections.bag.HashBag;
import org.apache.commons.io.input.CloseShieldInputStream;
import org.apache.commons.io.output.CloseShieldOutputStream;
import org.apache.commons.io.output.CountingOutputStream;
import org.apache.commons.lang3.tuple.Pair;
import org.lantern.util.BitInputStream;
import org.lantern.util.BitOutputStream;
import org.littleshoot.util.BitUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.csvreader.CsvReader;
import com.csvreader.CsvWriter;
import com.sachingarg.CompressedOutputStream;
import com.sachingarg.DecompressedInputStream;
import com.sachingarg.FenwickTreeModel;
import com.sachingarg.RCModel;

import it.unimi.dsi.fastutil.ints.IntList;
import it.unimi.dsi.fastutil.ints.IntArrayList;

//current status:
//this is waiting on me researching compression libraries
//to find one which will do my range coding (and maybe
//even my adaptive markov) for me

/**
 * Compresses the MaxMind GeoLite database for Lantern. This compression method
 * is optimized for Lantern-UI use; much data is discarded.
 *
 * Only countries and screen-resolution lat/lon are preserved.
 *
 * The data must be decompressed before use.
 */

public class GeoIpCompressor {
    private static final Logger LOG = LoggerFactory
            .getLogger(GeoIpCompressor.class);

    public static final int SCREEN_WIDTH = 960;
    public static final int SCREEN_HEIGHT = 625;

    // the quantized lat/lon is stored as lon + lat * SCREEN_WIDTH
    IntList pixelIdToQuantizedLatLon = new IntArrayList();
    IntList pixelIdToCountry = new IntArrayList();

    Map<String, Integer> countryToCountryId = new HashMap<String, Integer>();
    List<String> countryIdToCountry = new ArrayList<String>();

    // there is a relatively small number of pixels that cities quantize to,
    // so we'll give each one an id. This is the internal ID (and index
    // into the pixelIdToQuantiedLatLon list)
    Map<Pair<Integer, Integer>, Integer> quantizedLocationToPixelId = new HashMap<Pair<Integer, Integer>, Integer>();

    // maps from the database's location id to our pixel id
    Map<Integer, Integer> locIdToPixelId = new HashMap<Integer, Integer>();

    Bag rangeCounts = new HashBag();

    final IntList ipRangeList = new IntArrayList();
    final IntList pixelIdList = new IntArrayList();

    public GeoIpCompressor() {
    }

    /**
     * Returns the latitude and longitude, quantized to screen resolution
     * (960x625)
     *
     * @return
     */
    public int quantizedLatLon(double lat, double lon) {
        int quantizedLon = (int) ((lon + 180) * SCREEN_WIDTH / 360);
        int quantizedLat = (int) ((lat + 90) * SCREEN_HEIGHT / 180);

        return quantizedLat * SCREEN_WIDTH + quantizedLon;
    }

    public double getLatFromQuantized(int quantized) {
        int scaledLat = quantized / SCREEN_WIDTH;
        return ((float) scaledLat) * 180 / SCREEN_HEIGHT - 90;
    }

    public double getLonFromQuantized(int quantized) {
        int scaledLon = quantized % SCREEN_WIDTH;
        return ((float) scaledLon) * 360 / SCREEN_WIDTH - 180;
    }

    /**
     *
     * @param in
     *            The directory containing the input CSV files
     * @param out
     *            The filename of the compressed output file
     */
    public static void compress(File in, File out) throws IOException {
        GeoIpCompressor compressor = new GeoIpCompressor();

        compressor.compressInternal(in, out);
    }

    /**
     * Generates files lantern-locations.csv and lantern-blocks.csv in the
     * directory specified by out
     *
     * @param in
     * @param out
     * @throws IOException
     */
    public static void decompress(File in, File out) throws IOException {
        GeoIpCompressor compressor = new GeoIpCompressor();
        compressor.decompressInternal(in, out);
    }

    private void decompressInternal(File in, File out) throws IOException {
        LOG.debug("Decompressing GeoIp database to CSV");
        File locationFile = new File(out, "lantern-location.csv");
        File blockFile = new File(out, "lantern-blocks.csv");

        InputStream inStream = new BufferedInputStream(new FileInputStream(in));
        readCompressedData(inStream);

        writeDecompressedLocations(locationFile);
        writeDecompressedBlocks(blockFile);
        LOG.debug("Done decompressing");
    }

    public void readCompressedData(InputStream inStream) throws FileNotFoundException,
            IOException {
        readCompressedLocations(inStream);
        readCompressedBlocks(inStream);
    }

    private void writeDecompressedBlocks(File blockFile) throws IOException {
        CsvWriter writer = new CsvWriter(blockFile.getAbsolutePath());

        writer.writeComment("Derived from MaxMind GeoLiteCity.  Copyright (c) 2012 MaxMind LLC.");
        writer.writeRecord(new String[] { "startIpNum", "endIpNum", "pixelId" });

        long start = 0;
        for (int i = 0; i < ipRangeList.size(); ++i) {
            int ipRange = ipRangeList.get(i);
            int pixelId = pixelIdList.get(i);
            long end = start + ipRange - 1;
            writer.writeRecord(new String[] { "" + start, "" + end,
                    "" + pixelId });
            start = end + 1;
        }
        writer.close();

    }

    private void readCompressedBlocks(InputStream inStream) throws IOException {

        // the range sizes which only appear once
        IntList singletons = new IntArrayList();

        int count = 0;
        while (true) {
            if (count++ > 500000) {
                throw new RuntimeException("Unexpectedly large number of singleton locations (probably a corrupt geoip.db)");
            }
            byte[] b = new byte[4];
            inStream.read(b);
            int i = BitUtils.byteArrayToInteger(b);
            if (i == -1)
                break;
            singletons.add(i);
        }

        IntList rangeSizes = new IntArrayList();

        rangeSizes.add(0); // special case for singletons
        while (true) {
            byte[] b = new byte[4];
            inStream.read(b);
            int i = BitUtils.byteArrayToInteger(b);
            if (i == -1)
                break;
            rangeSizes.add(i);
        }

        int singleton = 0;

        // now read in the compressed blocks
        InputStream shielded = new CloseShieldInputStream(inStream);

        RCModel model = new FenwickTreeModel(rangeSizes.size());
        DecompressedInputStream compressedStream = new DecompressedInputStream(
                shielded, model);

        while (true) {
            int i = compressedStream.read();
            if (i == -1) {
                break;
            }
            int range = rangeSizes.get(i);
            if (range == 0) {
                range = singletons.get(singleton++);
            }
            ipRangeList.add(range);
        }
        compressedStream.close();

        // and the locations-for-blocks
        shielded = new CloseShieldInputStream(inStream);

        // Order1Model model2 = new Order1Model(pixelIdToQuantizedLatLon.size(),
        // pixelIdToCountry, countryIdToCountry.size());
        RCModel model2 = new FenwickTreeModel(pixelIdToQuantizedLatLon.size());
        DecompressedInputStream compressedStream2 = new DecompressedInputStream(
                shielded, model2);

        // model2.setPrevious(pixelIdToCountry.get(compressedStream2._nextByte));
        while (true) {
            int pixelId = compressedStream2.read();
            if (pixelId == -1) {
                break;
            }
            pixelIdList.add(pixelId);
            /*
             * if (compressedStream2._nextByte == -1) break;
             * model2.setPrevious(pixelIdToCountry
             * .get(compressedStream2._nextByte));
             */
        }
        compressedStream2.close();
        assert pixelIdList.size() == ipRangeList.size();
    }

    private void writeDecompressedLocations(File locationFile)
            throws IOException {
        CsvWriter writer = new CsvWriter(locationFile.getAbsolutePath());

        writer.writeComment("Derived from MaxMind GeoLiteCity.  Copyright (c) 2012 MaxMind LLC.");
        writer.writeRecord(new String [] {"pixelId","country","latitude","longitude"});

        for (int i = 0; i < pixelIdToCountry.size(); ++i) {
            int countryId = pixelIdToCountry.get(i);
            String country = countryIdToCountry.get(countryId);
            int quantized = pixelIdToQuantizedLatLon.get(i);
            double latitude = getLatFromQuantized(quantized);
            double longitude = getLonFromQuantized(quantized);
            writer.writeRecord(new String[] { "" + i, country, "" + latitude,
                    "" + longitude });
        }
        writer.close();
    }

    private void readCompressedLocations(InputStream inStream)
            throws IOException {
        byte[] b = new byte[4];
        inStream.read(b);
        int numPixelIds = BitUtils.byteArrayToInteger(b);
        LOG.debug("nPixelIds = " + numPixelIds);
        BitInputStream bitStream = new BitInputStream(inStream);

        for (int i = 0; i < numPixelIds; ++i) {
            pixelIdToQuantizedLatLon.add(bitStream.read(20));
        }
        bitStream.flush();

        // read in the list of countries ordered by id
        inStream.read(b);
        int nCountries = BitUtils.byteArrayToInteger(b);
        LOG.debug("nCountries = " + nCountries);
        for (int i = 0; i < nCountries; ++i) {
            byte[] countryCodeBytes = new byte[2];
            inStream.read(countryCodeBytes);
            String country = new String(countryCodeBytes);
            countryIdToCountry.add(country);
        }

        // read in the country for each pixel id
        RCModel model = new FenwickTreeModel(nCountries);

        InputStream shielded = new CloseShieldInputStream(inStream);
        InputStream compressedStream = new DecompressedInputStream(shielded,
                model);

        while (true) {
            int read = compressedStream.read();
            if (read == -1) {
                break;
            }
            pixelIdToCountry.add(read);
        }
        compressedStream.close();

    }

    private void compressInternal(File in, File out) throws IOException {
        File locationFile = new File(in, "GeoLiteCity-Location.csv");

        readLocations(locationFile);

        CountingOutputStream outStream = new CountingOutputStream(
                new BufferedOutputStream(new FileOutputStream(out)));

        writeCompressedLocations(outStream);

        LOG.debug("Bytes used after writing locations: "
                + outStream.getByteCount());

        File blocksFile = new File(in, "GeoLiteCity-Blocks.csv");
        readBlocks(blocksFile);
        writeCompressedBlocks(outStream);
        outStream.close();

        LOG.debug("Done writing compressed GeoIp file");
    }

    private void readBlocks(File blocksFile) throws IOException {
        CsvReader reader = new CsvReader(blocksFile.getAbsolutePath(), ',',
                Charset.forName("UTF8"));
        reader.setTextQualifier('"');
        reader.skipLine();
        reader.readHeaders();

        int lastPixelId = -1;
        long lastStartIpNum = -1;

        long endIpNum = -1;
        int pixelId;
        while (reader.readRecord()) {
            long startIpNum = Long.parseLong(reader.get("startIpNum"));
            endIpNum = Long.parseLong(reader.get("endIpNum"));
            int locId = Integer.parseInt(reader.get("locId"));

            pixelId = locIdToPixelId.get(locId);

            if (lastStartIpNum == -1) {
                // first range does not start at zero... but we'll pretend it
                // does
                lastStartIpNum = 0;
                lastPixelId = pixelId;
                continue;
            }

            if (pixelId != lastPixelId) {
                // store the previous range
                int range = (int) (startIpNum - lastStartIpNum);
                ipRangeList.add(range);
                rangeCounts.add(range);
                pixelIdList.add(lastPixelId);

                lastStartIpNum = startIpNum;
                lastPixelId = pixelId;
            }
        }
        // handle the last range;
        int range = (int) (endIpNum - lastStartIpNum + 1);
        ipRangeList.add(range);
        rangeCounts.add(range);
        pixelIdList.add(lastPixelId);
    }

    private void writeCompressedLocations(CountingOutputStream outStream)
            throws IOException {

        int numLocations = pixelIdToQuantizedLatLon.size();
        LOG.debug(numLocations + " pixel ids");
        outStream.write(BitUtils.toByteArray(numLocations));
        BitOutputStream bitStream = new BitOutputStream(outStream);
        for (int quantized : pixelIdToQuantizedLatLon) {
            bitStream.write(quantized, 20);
        }
        bitStream.flush();

        LOG.debug("Bytes used after quantized: " + outStream.getByteCount());
        outStream.write(BitUtils.toByteArray(countryIdToCountry.size()));
        // write out the list of countries by id
        for (String country : countryIdToCountry) {
            outStream.write(country.getBytes());
        }
        LOG.debug("Bytes used after country: " + outStream.getByteCount());

        // write out the range-coded countries for pixel ids
        RCModel model = new FenwickTreeModel(countryToCountryId.size());

        CloseShieldOutputStream shielded = new CloseShieldOutputStream(
                outStream);
        CompressedOutputStream compressedStream = new CompressedOutputStream(
                shielded, model);

        for (int countryId : pixelIdToCountry) {
            compressedStream.write(countryId);
        }
        compressedStream.close();

    }

    private void writeCompressedBlocks(CountingOutputStream outStream)
            throws IOException {
        // write out the blocks themselves

        // first, let's write out the sizes of all of the ranges, in order of
        // appearance

        final HashMap<Integer, Integer> rangeNumbering = new HashMap<Integer, Integer>();
        for (int range : ipRangeList) {
            if (rangeCounts.getCount(range) <= 2) {
                outStream.write(BitUtils.toByteArray(range));
                // all singletons are zeroes;
                // treat doubletons as singletons
                rangeNumbering.put(range, 0);
            }
        }
        outStream.write(BitUtils.toByteArray(-1));

        LOG.debug("Bytes used after singletons/doubletons: "
                + outStream.getByteCount());
        int number = 1;
        for (int range : ipRangeList) {
            if (rangeCounts.getCount(range) > 2) {
                if (!rangeNumbering.containsKey(range)) {
                    rangeNumbering.put(range, number++);
                    outStream.write(BitUtils.toByteArray(range));
                }
            }
        }
        outStream.write(BitUtils.toByteArray(-1));
        LOG.debug("Bytes used after other range sizes: "
                + outStream.getByteCount());

        CloseShieldOutputStream shielded = new CloseShieldOutputStream(
                outStream);

        // now write out the compressed blocks
        RCModel model = new FenwickTreeModel(number);

        CompressedOutputStream compressedStream = new CompressedOutputStream(
                shielded, model);
        for (int range : ipRangeList) {
            compressedStream.write(rangeNumbering.get(range));
        }
        compressedStream.close();

        LOG.debug("Bytes used after iprangelist: " + outStream.getByteCount());

        shielded = new CloseShieldOutputStream(outStream);

        // Write the compressed locations for each block

        // This order-1 model conditions on the country of the previous
        // location
        /*
         * Order1Model model2 = new Order1Model(pixelIdToCountry.size(),
         * pixelIdToCountry, countryIdToCountry.size());
         */
        RCModel model2 = new FenwickTreeModel(pixelIdToCountry.size());
        compressedStream = new CompressedOutputStream(shielded, model2);
        for (int pixelId : pixelIdList) {
            compressedStream.write(pixelId);
        }
        compressedStream.close();

        LOG.debug("Bytes used after pixelidlist: " + outStream.getByteCount());
    }

    /**
     * read in the locations csv file and set up location mappings
     *
     * @param locationFile
     */
    private void readLocations(File locationFile) throws IOException {
        CsvReader reader = new CsvReader(locationFile.getAbsolutePath(), ',',
                Charset.forName("UTF8"));
        reader.skipLine();
        reader.readHeaders();

        int nextPixelId = 0;
        int nextCountryId = 0;

        while (reader.readRecord()) {
            double lat = Double.parseDouble(reader.get("latitude"));
            double lon = Double.parseDouble(reader.get("longitude"));
            String country = reader.get("country");
            country = normalizeCountry(country);

            Integer countryId = countryToCountryId.get(country);
            if (countryId == null) {
                countryId = nextCountryId++;
                countryToCountryId.put(country, countryId);
                countryIdToCountry.add(country);
            }

            int locId = Integer.parseInt(reader.get("locId"));

            int quantized = quantizedLatLon(lat, lon);
            Pair<Integer, Integer> key = Pair.of(quantized, countryId);
            Integer pixelId = quantizedLocationToPixelId.get(key);
            if (pixelId == null) {
                pixelId = nextPixelId++;
                pixelIdToQuantizedLatLon.add(quantized);
                pixelIdToCountry.add(countryId);
                quantizedLocationToPixelId.put(key, pixelId);
            }
            locIdToPixelId.put(locId, pixelId);
        }

    }

    /** normalize all null islands to one place */
    private String normalizeCountry(String country) {
        if (country.equals("A1") || country.equals("A2")) {
            country = "O1";
        }
        return country;
    }
}
