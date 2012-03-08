package org.lantern.privacy; 

import java.io.File;
import java.io.IOError;
import java.io.IOException;
import java.security.Key;
import java.security.GeneralSecurityException;
import java.security.spec.KeySpec;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.PBEParameterSpec;

import org.lantern.LanternBrowser;
import org.lantern.LanternHub;
import org.lantern.LanternUtils;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * DefaultLocalCipherProvider
 *
 * This is a LocalCipherProvider that uses password 
 * based encryption (PBE) and prompts the user for some 
 * secret.
 * 
 * The user is asked to set and enter passwords to 
 * decrypt local information on each run of the program
 * and to set a password on the first run.
 *
 */
public class DefaultLocalCipherProvider extends AbstractLocalCipherProvider {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public DefaultLocalCipherProvider() {
        super();
    }
    
    public DefaultLocalCipherProvider(final File validatorFile, final File cipherParamsFile) {
        super(validatorFile, cipherParamsFile);
    }
    
    @Override
    String getAlgorithm() {
        return "PBEWithSHA1AndDESede";
    }
    
    @Override
    void initializeCipher(Cipher cipher, int opmode, Key key) throws GeneralSecurityException {
        byte [] salt = new byte[8]; 
        LanternHub.secureRandom().nextBytes(salt);
        cipher.init(opmode, key, new PBEParameterSpec(salt, 100));
    }
    
    @Override
    Key getLocalKey(boolean init) throws IOException, GeneralSecurityException {
        
        char[] password = null;
        byte[] rawKey = null;
        byte[] validator = null;
        int tries = 0;
        
        try {
            while (true) {
                if (tries > 0) {
                    log.info("Incorrect password.");
                }
                zeroFill(password);
                zeroFill(rawKey);

                if (LanternHub.settings().isUiEnabled()) {
                    password = getPasswordGUI(init, tries);
                }
                else {
                    password = getPasswordCLI(init, tries);
                }
                
                final KeySpec keySpec = new PBEKeySpec(password);
                final SecretKeyFactory keyFactory = SecretKeyFactory.getInstance(getAlgorithm());
                final SecretKey key = keyFactory.generateSecret(keySpec);
                rawKey = key.getEncoded();

                if (init) {
                    validator = createValidator(rawKey);
                    storeValidator(validator);
                    return key;
                }
                else {
                    if (validator == null) {
                        validator = loadValidator();
                    }
                    if (checkKeyValid(rawKey, validator)) {
                        return key;
                    }
                }
                tries += 1;
            }
        } catch (IOError e) {
            throw new IOException(e.getMessage());
        }
        finally {
            zeroFill(password);
            zeroFill(rawKey);
        }
    }

    char[] getPasswordGUI(boolean init, int tries) {
        if (init) {
            LanternBrowser browser = new LanternBrowser(false);
            return browser.setLocalPassword();
        }
        else {
            LanternBrowser browser = new LanternBrowser(false);
            return browser.getLocalPassword(new LanternBrowser.PasswordValidator() {
                @Override
                public boolean passwordIsValid(char [] password) throws Exception {
                    return checkPasswordValid(password);
                }
            });
       }
    }
    
    boolean checkPasswordValid(char [] password) throws IOException, GeneralSecurityException {
        byte [] rawKey = null;
        try {
            final KeySpec keySpec = new PBEKeySpec(password);
            final SecretKeyFactory keyFactory = SecretKeyFactory.getInstance(getAlgorithm());
            final SecretKey key = keyFactory.generateSecret(keySpec);
            rawKey = key.getEncoded();
            return checkKeyValid(rawKey, loadValidator());
        } finally {
            zeroFill(rawKey);
        }
    }

    char[] getPasswordCLI(boolean init, int tries) throws IOException {
        if (init) {
            while (true) {
                System.out.print("Please enter a password to protect your local data:");
                System.out.flush();
                final char [] pw1 = LanternUtils.readPasswordCLI();
                if (pw1.length == 0) {
                    System.out.println("password cannot be blank, please try again.");
                    System.out.flush();
                    continue;
                }
                System.out.print("Please enter password again:");
                System.out.flush();
                final char [] pw2 = LanternUtils.readPasswordCLI();
                if (Arrays.equals(pw1, pw2)) {
                    // zero out pw2
                    zeroFill(pw2);
                    return pw1;
                }
                else {
                    zeroFill(pw1);
                    zeroFill(pw2);
                    System.out.println("passwords did not match, please try again.");
                    System.out.flush();
                }
            }
        }
        else {
            if (tries > 0) {
                System.out.println("Sorry, that password is incorrect.");
            }
            System.out.print("Please enter your lantern password:");
            System.out.flush();
            return LanternUtils.readPasswordCLI();
        }
    }
}