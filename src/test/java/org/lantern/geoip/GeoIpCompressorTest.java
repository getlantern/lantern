package org.lantern.geoip;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.List;

import org.junit.Test;
import org.lantern.GeoData;
import org.lantern.TestUtils;

import com.csvreader.CsvReader;
import com.google.common.io.Files;

public class GeoIpCompressorTest {
    @Test
    public void test() throws IOException {
        URL resource = getClass().getClassLoader().getResource("GeoIpTestData");
        File path = new File(resource.getPath());
        File tmp = File.createTempFile("compressed", ".db");
        File tmpDir = Files.createTempDir();
        tmp.deleteOnExit();
        tmpDir.deleteOnExit();
        GeoIpCompressor.compress(path, tmp);
        GeoIpCompressor.decompress(tmp, tmpDir);

        List<Location> got = readLocationCSV(new File(tmpDir,
                "lantern-location.csv"));
        List<Location> expected = readLocationCSV(new File(path,
                "lantern-location-expected.csv"));
        assertEquals(got.size(), expected.size());
        for (int i = 0; i < got.size(); ++i) {
            Location gotLoc = got.get(i);
            Location expectedLoc = expected.get(i);
            assertEquals(expectedLoc.country, gotLoc.country);
            assertTrue(Math.abs(expectedLoc.latitude - gotLoc.latitude) < 1);
            assertTrue(Math.abs(expectedLoc.longitude - gotLoc.longitude) < 1);
        }

        List<Block> gotBlocks = readBlocksCSV(new File(tmpDir,
                "lantern-blocks.csv"));
        List<Block> expectedBlocks = readBlocksCSV(new File(path,
                "lantern-blocks-expected.csv"));
        assertEquals(expectedBlocks, gotBlocks);

    }

    @Test
    public void testLookupService() {
        GeoIpLookupService lookupService = TestUtils.getGeoIpLookupService();
        //check that data loads
        assertEquals("US", lookupService.getGeoData("18.1.1.1").getCountrycode());
        assertEquals("IN", lookupService.getGeoData("223.255.244.1").getCountrycode());

        final GeoData data = lookupService.getGeoData("86.170.128.133");
        assertTrue(data.getLatitude() > 50.0);
        assertTrue(data.getLongitude() < 3.0);
        assertEquals("GB", data.getCountrycode());

        final GeoData data2 = lookupService.getGeoData("87.170.128.133");
        assertTrue(data2.getLatitude() > 50.0);
        assertTrue(data2.getLongitude() > 13.0);
        assertEquals("DE", data2.getCountrycode());
    }

    private static class Location {
        public double latitude;
        public double longitude;
        public String country;
    }

    private static class Block {
        public int startIp, endIp, pixelId;

        @Override
        public boolean equals(Object other) {
            Block o = (Block) other;
            return o.startIp == startIp &&
                   o.endIp == endIp &&
                   o.pixelId == pixelId;
        }

        @Override
        public String toString() {
            return "Block(" + startIp + ", " + endIp + ", " + pixelId + ")";
        }
    }

    private List<Location> readLocationCSV(File filename) throws IOException {
        CsvReader reader = new CsvReader(filename.getAbsolutePath(), ',',
                Charset.forName("UTF8"));
        reader.setTextQualifier('"');
        reader.skipLine();
        reader.readHeaders();
        ArrayList<Location> locations = new ArrayList<Location>();
        while (reader.readRecord()) {
            double lat = Double.parseDouble(reader.get("latitude"));
            double lon = Double.parseDouble(reader.get("longitude"));
            String country = reader.get("country");
            Location location = new Location();
            location.latitude = lat;
            location.longitude = lon;
            location.country = country;
            locations.add(location);
        }
        return locations;
    }

    private List<Block> readBlocksCSV(File filename) throws IOException {
        CsvReader reader = new CsvReader(filename.getAbsolutePath(), ',',
                Charset.forName("UTF8"));
        reader.setTextQualifier('"');
        reader.skipLine();
        reader.readHeaders();
        ArrayList<Block> blocks = new ArrayList<Block>();
        while (reader.readRecord()) {
            int startIp = Integer.parseInt(reader.get("startIpNum"));
            int endIp = Integer.parseInt(reader.get("endIpNum"));
            int pixelId = Integer.parseInt(reader.get("pixelId"));
            Block block = new Block();
            block.startIp = startIp;
            block.endIp = endIp;
            block.pixelId = pixelId;
            blocks.add(block);
        }
        return blocks;
    }
}
