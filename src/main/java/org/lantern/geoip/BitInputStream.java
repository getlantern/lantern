package org.lantern.geoip;

import java.io.IOException;
import java.io.InputStream;

public class BitInputStream {
    private final InputStream stream;
    private int remainingBits = 0;
    private byte toReturn = 0;

    public BitInputStream(InputStream stream) {
        this.stream = stream;
    }

    /**
     * Writes the least-significant bits of value to the stream, MSB first
     */
    public int read(int bits) throws IOException {
        int ret = 0;
        for (int i = 0; i < bits; ++i) {
            ret <<= 1;
            ret |= readBit();
        }
        return ret;
    }

    private int readBit() throws IOException {
        if (remainingBits == 0) {
            int read = stream.read();
            if (read == -1) {
                throw new IOException("Out of bits reading bitstream");
            }
            toReturn = (byte) read;
            remainingBits = 8;
        }
        remainingBits--;
        int r = (toReturn & (1 << remainingBits)) >> remainingBits;
        return r;
    }

    public void flush() {
        remainingBits = 0;
    }
}
