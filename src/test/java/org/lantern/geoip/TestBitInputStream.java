package org.lantern.geoip;

import static org.junit.Assert.assertEquals;

import java.io.ByteArrayInputStream;
import java.io.IOException;

import org.junit.Test;

public class TestBitInputStream {
    @Test
    public void test() throws IOException {
        //write 0000 0000  1011 0110  1101 1010
        byte[] bytes = new byte[] {0,(byte)182,(byte)218};

        ByteArrayInputStream inStream = new ByteArrayInputStream(bytes);
        BitInputStream bitInputStream = new BitInputStream(inStream);
        int bits = bitInputStream.read(7);
        assertEquals(0, bits);
        bitInputStream.flush(); //move to byte boundary

        bits = bitInputStream.read(9);
        //101101101
        assertEquals(365, bits);
    }
}
