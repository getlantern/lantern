package org.lantern.privacy; 

import java.io.File;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.SecureRandom;
import java.security.spec.KeySpec;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.PBEParameterSpec;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This is a LocalCipherProvider that uses password based encryption (PBE) 
 * and prompts the user for some secret.
 * 
 * The user is asked to set and enter passwords to decrypt local information 
 * on each run of the program and to set a password on the first run.
 *
 */
public class DefaultLocalCipherProvider extends AbstractLocalCipherProvider {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final SecureRandom secureRandom = new SecureRandom();
    
    public DefaultLocalCipherProvider() {
        super();
    }
    
    public DefaultLocalCipherProvider(final File validatorFile, 
        final File cipherParamsFile) {
        super(validatorFile, cipherParamsFile);
    }
    
    @Override
    String getAlgorithm() {
        return "PBEWithSHA1AndDESede";
    }
    
    @Override
    void initializeCipher(Cipher cipher, int opmode, Key key) 
        throws GeneralSecurityException {
        final byte [] salt = new byte[8]; 
        secureRandom.nextBytes(salt);
        cipher.init(opmode, key, new PBEParameterSpec(salt, 100));
    }
    
    @Override
    public boolean requiresAdditionalUserInput() { 
        return !hasLocalKey();
    }
    
    @Override
    public void feedUserInput(final char [] input, final boolean init)
        throws IOException, GeneralSecurityException {
    
        byte[] rawKey = null;
        byte[] validator = null;

        try {
            // basic validation
            if (input.length == 0) {
                if (init) {
                    throw new InvalidKeyException("Password cannot be blank");
                }
                else {
                    throw new InvalidKeyException("Incorrect Password");
                }
            }
        
            final KeySpec keySpec = new PBEKeySpec(input);
            final SecretKeyFactory keyFactory = 
                SecretKeyFactory.getInstance(getAlgorithm());
            final SecretKey key = keyFactory.generateSecret(keySpec);
            rawKey = key.getEncoded();

            // if initializing, just set it
            if (init) {
                validator = createValidator(rawKey);
                storeValidator(validator);
                feedLocalKey(key);
            }
            // if not initializing, check validity before setting
            else {
                if (validator == null) {
                    validator = loadValidator();
                }
                if (checkKeyValid(rawKey, validator)) {
                    feedLocalKey(key);
                }
                else {
                    throw new InvalidKeyException("Incorrect Password");
                }
            }
        }
        finally {
            zeroFill(rawKey);
        }
    }
    
    @Override
    Key getLocalKey(boolean init) throws UserInputRequiredException {
        // user key data must be fed in.  If it has been, this should not be called.
        throw new UserInputRequiredException("Password has not been provided");
    }
    
}