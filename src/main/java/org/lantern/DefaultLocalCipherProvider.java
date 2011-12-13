package org.lantern; 

import java.io.File;
import java.io.IOError;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.Charset;
import java.nio.charset.CharsetEncoder;
import java.nio.charset.CoderResult;
import java.security.MessageDigest;
import java.security.GeneralSecurityException;
import java.security.spec.KeySpec;
import java.security.SecureRandom;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.SecretKey; 
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.PBEParameterSpec;
import org.apache.commons.io.FileUtils;

import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Dialog;
import org.eclipse.swt.widgets.Display; 
import org.eclipse.swt.widgets.Event; 
import org.eclipse.swt.widgets.Label; 
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Shell; 
import org.eclipse.swt.widgets.Text;

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
    
    public static final File DEFAULT_VALIDATOR_FILE = 
        new File(LanternUtils.configDir(), "cipher.validator");
    private static final int VALIDATOR_SALT_BYTES = 8;
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final File validatorFile;
    
    public DefaultLocalCipherProvider() {
        this(DEFAULT_VALIDATOR_FILE, DEFAULT_CIPHER_PARAMS_FILE);
    }
    
    public DefaultLocalCipherProvider(final File validatorFile, final File cipherParamsFile) {
        super(cipherParamsFile);
        this.validatorFile = validatorFile;
    }
    
    @Override
    String getAlgorithm() {
        return "PBEWithSHA1AndDESede";
    }
    
    @Override
    void initializeCipher(Cipher cipher, int opmode, SecretKey key) throws GeneralSecurityException {
        byte [] salt = new byte[8]; 
        LanternHub.secureRandom().nextBytes(salt);
        cipher.init(opmode, key, new PBEParameterSpec(salt, 100));
    }
    
    @Override
    KeySpec getLocalKeySpec(boolean init) throws IOException, GeneralSecurityException {
        
        char[] password = null;
        boolean passwordValid = false;
        int tries = 0;
        
        try {
            while (!passwordValid) {
                if (tries > 0) {
                    log.info("Incorrect password.");
                }
                zeroFill(password);

                if (LanternUtils.runWithUi()) {
                    password = getPasswordGUI(init, tries);
                }
                else {
                    password = getPasswordCLI(init, tries);
                }

                if (init) {
                    passwordValid = true;
                    storeValidatorFor(password);
                }
                else {
                    passwordValid = checkPasswordValid(password);
                }
                tries += 1;
            }
            KeySpec keySpec = new PBEKeySpec(password);
            return keySpec;
        } catch (IOError e) {
            throw new IOException(e.getMessage());
        }
        finally {
            zeroFill(password);
        }
    }
    
    boolean checkPasswordValid(char[] password) throws IOException, GeneralSecurityException {
        if (!validatorFile.isFile()) {
            return false;
        }
        final byte[] validator = loadValidator();
        final byte[] salt = Arrays.copyOf(validator, VALIDATOR_SALT_BYTES);
        return Arrays.equals(validator, createValidator(password, salt));
    }
    
    byte[] createValidator(char [] password, byte[] salt) throws IOException, GeneralSecurityException {
        // the validator is the concatenation of the salt value 
        // and the sha256 digest of the salt and the utf-8 encoded password.
        final byte[] passwordBytes = new byte[password.length*2];
        try {
            // encode password in utf-8
            final Charset charset = Charset.forName("UTF-8");
            final CharsetEncoder encoder = charset.newEncoder();
            CoderResult cr = encoder.encode(CharBuffer.wrap(password), ByteBuffer.wrap(passwordBytes), true);
            if (cr.isError()) {
                throw new IOException("Unable to encode password.");
            }

            // create digest        
            final MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(salt);
            md.update(passwordBytes);
            final byte[] hash = md.digest();
            final byte[] validator = new byte[salt.length + hash.length];
            System.arraycopy(salt, 0, validator, 0, salt.length);
            System.arraycopy(hash, 0, validator, salt.length, hash.length);
            return validator; 
        }
        finally {
            zeroFill(passwordBytes);
        }
    }
    
    byte[] loadValidator() throws IOException {
        return FileUtils.readFileToByteArray(validatorFile);
    }
    
    /** 
     * create and store a new validator for the password given.
     */
    void storeValidatorFor(char []password) throws IOException, GeneralSecurityException {
        // generate new salt bytes
        final byte[] salt = new byte[VALIDATOR_SALT_BYTES];
        final SecureRandom secureRandom = LanternHub.secureRandom();
        secureRandom.nextBytes(salt);
        final byte[] validator = createValidator(password, salt);
        FileUtils.writeByteArrayToFile(validatorFile, validator);
    }
    
    void zeroFill(char[] array) {
        if (array != null) {
            Arrays.fill(array, '\0');
        }
    }

    void zeroFill(byte[] array) {
        if (array != null) {
            Arrays.fill(array, (byte) 0);
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
                public boolean passwordIsValid(char [] password) throws Exception {
                    return checkPasswordValid(password);
                }
            });
       }
    }
    
    char[] getPasswordCLI(boolean init, int tries) throws IOException {
        if (init) {
            while (true) {
                System.out.print("Please enter a password to protect your local data:");
                System.out.flush();
                final char [] pw1 = LanternUtils.readPasswordCLI();
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