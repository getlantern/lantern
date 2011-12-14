package org.lantern; 

import com.mcdermottroe.apple.OSXKeychain;
import com.mcdermottroe.apple.OSXKeychainException;
import java.io.File;
import java.io.IOException;
import java.math.BigInteger;
import java.util.Arrays;
import java.security.GeneralSecurityException;
import org.apache.commons.codec.binary.Base64;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * MacLocalCipherProvider
 *
 * This is a LocalCipherProvider that uses 
 * the OS X KeyChain to store a local key
 * used to encrypt/decrypt local data.
 *
 */
public class MacLocalCipherProvider extends AbstractAESLocalCipherProvider {

    private static final String SERVICE_NAME = "Lantern Local Privacy";
    private static final String ACCOUNT_NAME = "lantern";

    private final Logger log = LoggerFactory.getLogger(getClass());    

    MacLocalCipherProvider() {
        this(DEFAULT_CIPHER_PARAMS_FILE);
    }
    
    MacLocalCipherProvider(final File cipherParamsFile) {
        super(cipherParamsFile);
    }

    byte[] loadKeyData() throws IOException, GeneralSecurityException {
        try {
            OSXKeychain keychain = OSXKeychain.getInstance();
            Base64 base64 = new Base64();
            String encodedKey = keychain.findGenericPassword(SERVICE_NAME, ACCOUNT_NAME);
            return base64.decode(encodedKey.getBytes());
        } catch (OSXKeychainException e) {
            throw new GeneralSecurityException(e);
        }
    }

    void storeKeyData(byte[] key) throws IOException, GeneralSecurityException {
        Base64 base64 = new Base64();
        byte [] encodedKey = base64.encode(key);
        try {
            OSXKeychain keychain = OSXKeychain.getInstance();
            try {
                keychain.deleteGenericPassword(SERVICE_NAME, ACCOUNT_NAME);
                log.debug("Removing old lantern keychain entry...");
            } catch (OSXKeychainException e) { /* expected result */ }
            keychain.addGenericPassword(SERVICE_NAME, ACCOUNT_NAME, new String(encodedKey));
        } catch (OSXKeychainException e) {
            throw new GeneralSecurityException(e);
        } finally {
            Arrays.fill(encodedKey, (byte) 0);
        }
    }
}