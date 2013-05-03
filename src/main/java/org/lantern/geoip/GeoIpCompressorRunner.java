package org.lantern.geoip;

import java.io.File;
import java.io.IOException;


public class GeoIpCompressorRunner {
    public static void main(String[] args) {
        try {
            GeoIpCompressor.compress(new File("/home/leah/GeoLiteCity_20130402"), new File("/home/leah/GeoLiteCity_20130402/compressed.db"));
            GeoIpCompressor.decompress(new File("/home/leah/GeoLiteCity_20130402/compressed.db"), new File("/home/leah/GeoLiteCity_20130402"));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}
