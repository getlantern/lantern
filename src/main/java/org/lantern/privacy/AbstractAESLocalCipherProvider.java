package org.lantern.privacy; 

import java.io.File;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.spec.AlgorithmParameterSpec;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import org.lantern.LanternHub;
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
    
    public AbstractAESLocalCipherProvider(final File validatorFile, final File cipherParamsFile) {
        super(validatorFile, cipherParamsFile);
    }

    public AbstractAESLocalCipherProvider() {
        super();
    }

    @Override
    String getAlgorithm() {
        return "AES";
    }

    @Override
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
                byte [] validator = createValidator(rawKey);
                storeValidator(validator);
            }
            else {
                rawKey = loadKeyData();
                if (!checkKeyValid(rawKey, loadValidator())) {
                    throw new GeneralSecurityException("Stored key is incorrect or corrupt.");
                }
            }
            return new SecretKeySpec(rawKey, getAlgorithm());
        } finally {
            zeroFill(rawKey);
        }
    }
}