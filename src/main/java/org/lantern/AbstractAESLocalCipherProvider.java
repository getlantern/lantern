package org.lantern; 

import java.io.File;
import java.io.IOError;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.spec.KeySpec;
import java.security.spec.AlgorithmParameterSpec;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey; 
import javax.crypto.spec.SecretKeySpec;
import javax.crypto.spec.IvParameterSpec;
import org.apache.commons.io.FileUtils;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * AbstractAESLocalCipherProvider
 *
 * This is a LocalCipherProvider that uses AES and  
 * some secure local means to store a generated key.
 *
 */
public abstract class AbstractAESLocalCipherProvider extends AbstractLocalCipherProvider {
    
    
    private final Logger log = LoggerFactory.getLogger(getClass());


    abstract byte[] loadKeyData() throws IOException, GeneralSecurityException;    
    abstract void storeKeyData(byte [] key) throws IOException, GeneralSecurityException;
    
    public AbstractAESLocalCipherProvider(final File cipherParamsFile) {
        super(cipherParamsFile);
    }

    public AbstractAESLocalCipherProvider() {
        super();
    }

    @Override
    String getAlgorithm() {
        return "AES";
    }

    Cipher getCipher() throws GeneralSecurityException {
        return Cipher.getInstance("AES/CBC/PKCS5Padding");
    }

    @Override
    void initializeCipher(Cipher cipher, int opmode, Key key) throws GeneralSecurityException {
        byte[] iv = new byte[16];
        LanternHub.secureRandom().nextBytes(iv);
        AlgorithmParameterSpec params = new IvParameterSpec(iv);
        cipher.init(opmode, key, params);
    }

    int getKeyLength() {
        return 128; // XXX policy files
    }
        
    @Override
    Key getLocalKey(boolean init) throws IOException, GeneralSecurityException {
        
        byte [] rawKey = null;
        try {
            if (init) {
                // generate a new key
                final KeyGenerator kgen = KeyGenerator.getInstance(getAlgorithm());
                kgen.init(getKeyLength());
                final SecretKey key = kgen.generateKey();
                rawKey = key.getEncoded();
                storeKeyData(rawKey);
            }
            else {
                rawKey = loadKeyData();
            }
            return new SecretKeySpec(rawKey, getAlgorithm());
        } finally {
            if (rawKey != null) {
                Arrays.fill(rawKey, (byte) 0);
            }
        }
    }
}