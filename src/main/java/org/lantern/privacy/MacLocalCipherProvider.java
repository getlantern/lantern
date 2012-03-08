package org.lantern.privacy; 

import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;

import com.mcdermottroe.apple.OSXKeychain;
import com.mcdermottroe.apple.OSXKeychainException;
import java.io.File;
import java.io.IOException;
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

    public MacLocalCipherProvider() {
        super();
    }
    
    public MacLocalCipherProvider(final File validatorFile, final File cipherParamsFile) {
        super(validatorFile, cipherParamsFile);
    }

    @Override
    byte[] loadKeyData() throws IOException, GeneralSecurityException {
        try {
            OSXKeychain keychain = OSXKeychain.getInstance();
            final Base64 base64 = new Base64();
            final String encodedKey = keychain.findGenericPassword(SERVICE_NAME, ACCOUNT_NAME);
            return base64.decode(encodedKey.getBytes());
        } catch (OSXKeychainException e) {
            throw new GeneralSecurityException(e);
        }
    }

    @Override
    void storeKeyData(byte[] key) throws IOException, GeneralSecurityException {
        final Base64 base64 = new Base64();
        final byte [] encodedKey = base64.encode(key);
        try {
            OSXKeychain keychain = OSXKeychain.getInstance();
            String keyString = new String(encodedKey);
            try {
                keychain.modifyGenericPassword(SERVICE_NAME, ACCOUNT_NAME, keyString);
                log.debug("Replaced old lantern keychain entry.");
            } catch (OSXKeychainException e) {
                /* not found, add */
                keychain.addGenericPassword(SERVICE_NAME, ACCOUNT_NAME, keyString);
                log.debug("Created new lantern keychain entry.");
            }
        } catch (OSXKeychainException e) {
            throw new GeneralSecurityException(e);
        } finally {
            zeroFill(encodedKey);
        }
    }
}