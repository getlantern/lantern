package org.lantern.geoip;

import static org.junit.Assert.assertEquals;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import org.junit.Test;

public class TestBitOutputStream {
    @Test
    public void test() throws IOException {
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        BitOutputStream bitStream = new BitOutputStream(os);
        bitStream.flush();
        byte[] bytes = os.toByteArray();
        assertEquals(0, bytes.length);

        bitStream.write(5, 3);
        bitStream.flush();
        bytes = os.toByteArray();
        assertEquals((byte)160, bytes[0]);

        for (int i = 0; i < 5; ++i) {
            bitStream.write(5, 3);
        }
        bitStream.flush();
        bytes = os.toByteArray();
        assertEquals((byte)182, bytes[1]);
        assertEquals((byte)218, bytes[2]);


    }
}
