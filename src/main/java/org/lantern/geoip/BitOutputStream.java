package org.lantern.geoip;

import java.io.IOException;
import java.io.OutputStream;

/**
 * Writes bits to an output stream. Bits are written MSB-first.
 *
 * @author Leah X Schmidt
 *
 */
public class BitOutputStream {
    private final OutputStream stream;
    private int remainingBits = 8;
    private byte toWrite = 0;

    public BitOutputStream(OutputStream stream) {
        this.stream = stream;
    }

    /**
     * Writes the least-significant bits of value to the stream, MSB first
     */
    public void write(int value, int bits) throws IOException {
        for (int i = bits - 1; i >= 0; --i) {
            writeBit((value & (1 << i)) >> i);
        }
    }

    private void writeBit(int bit) throws IOException {
        remainingBits--;
        toWrite |= bit << remainingBits;
        if (remainingBits == 0) {
            stream.write(toWrite);
            remainingBits = 8;
            toWrite = 0;
        }
    }

    /**
     * Flushes out the last remaining bits of the last byte, if any
     */
    public void flush() throws IOException {
        if (remainingBits == 8) {
            return;
        }
        stream.write(toWrite);
        remainingBits = 8;
        toWrite = 0;
    }
}
