package org.lantern.geoip;

import java.io.File;
import java.io.IOException;

import org.lantern.geoip.GeoIpCompressor;

public class GeoIpCompressorRunner {
    public static void main(String[] args) {
        Args parsedArgs = parseArgs(args);
        if (parsedArgs == null) {
            System.err.println("Usage: GeoIpCompressorRunner compress $GeoLiteCity_directory $output_file");
            System.err.println("   or: GeoIpCompressorRunner decompress $compressed_file $output_directory");
            return;
        }

        try {
            if (parsedArgs.compress){
                GeoIpCompressor.compress(parsedArgs.dir, parsedArgs.compressed);
            } else {
                GeoIpCompressor.decompress(parsedArgs.compressed, parsedArgs.dir);
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private static class Args {
        /**
         * True for compression, false for decompression
         */
        public boolean compress;
        public File compressed;
        public File dir;
    }

    private static Args parseArgs(String[] args) {
        if (args.length != 3) {
            return null;
        }
        Args parsed = new Args();
        if ("compress".equals(args[0])) {
            parsed.compress = true;
            parsed.dir = new File(args[1]);
            parsed.compressed = new File(args[2]);

            if (!(parsed.dir.isDirectory() && parsed.dir.canRead())) {
                System.err.println("Argument " + parsed.dir + " must be a readable directory");
            }
            return parsed;
        } else if ("decompress".equals(args[0])) {
            parsed.compress = false;
            parsed.dir = new File(args[2]);
            parsed.compressed = new File(args[1]);

            if (!(parsed.compressed.isFile() && parsed.compressed.canRead())) {
                System.err.println("Argument " + parsed.compressed + " must be a readable file");
            }

            if (!(parsed.dir.isDirectory() && parsed.dir.canWrite())) {
                System.err.println("Argument " + parsed.dir + " must be a writeable directory");
            }
            return parsed;
        } else {
            return null;
        }
    }
}
