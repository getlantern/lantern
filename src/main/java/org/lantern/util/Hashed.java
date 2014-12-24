package org.lantern.util;

import java.security.MessageDigest;

import org.apache.commons.codec.binary.Hex;
import org.apache.commons.codec.digest.DigestUtils;

/**
 * Utility for hashing data.
 */
public class Hashed {
    private byte[] hash = new byte[0];

    /**
     * Hash the given data with the given salt, running through iters iterations
     * of the hashing algorithm.
     * 
     * @param salt
     * @param data
     * @param iters
     */
    public Hashed(byte[] salt, byte[] data, int iters) {
        for (int i=0; i<iters; i++) {
            MessageDigest digest = DigestUtils.getSha256Digest();
            digest.update(hash);
            digest.update(salt);
            hash = digest.digest(data);
        }
    }

    public byte[] hash() {
        return hash;
    }

    public String hashHex() {
        return Hex.encodeHexString(hash);
    }
}
