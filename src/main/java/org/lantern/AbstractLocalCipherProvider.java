package org.lantern;

import java.io.File;
import java.io.IOException;
import java.security.AlgorithmParameters;
import java.security.GeneralSecurityException;
import java.security.spec.KeySpec;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * AbstractLocalCipherProvider
 *
 * helper base class for LocalCipherProvider
 * implementations.
 *
 */
abstract class AbstractLocalCipherProvider implements LocalCipherProvider {

    public static File DEFAULT_CIPHER_PARAMS_FILE =
            new File(LanternUtils.configDir(), "cipher.params");
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final File paramsFile;
    private KeySpec keySpec = null;
    
    AbstractLocalCipherProvider() {
        this(DEFAULT_CIPHER_PARAMS_FILE);
    }
    AbstractLocalCipherProvider(File cipherParamsFile) {
        this.paramsFile = cipherParamsFile;
    }
    
    /** 
     * return the identifier for the algorithm that should be used
     * by the created Cipher and related classes -- eg "AES"
     */ 
    abstract String getAlgorithm();
    
    /**
     * return a KeySpec representing the user's secret value. 
     * if init is true, a new key should be generated or 
     * collected from the user. 
     *
     * @param init called if a new key should be generated/requested
     *        otherwise it should be expected that the key exists.
     */
    abstract KeySpec getLocalKeySpec(boolean init) throws IOException, GeneralSecurityException;

    /**
     * optional cipher initialization. This is only called when no 
     * local cipher parameters have yet been established. Parameters
     * set here are stored and loaded during subsequent calls / runs.
     *
     * By default, performs default initialization via cipher.init(opmode, key)
     *
     * @param cipher
     * @param opmode
     * @param key
     * @throws GeneralSecurityException
     */
    void initializeCipher(Cipher cipher, int opmode, SecretKey key) throws GeneralSecurityException {
        // default init
        cipher.init(opmode, key);
    }

    /**
     * @return File used to save and load cipher parameters
     */
    File getParametersFile() {
        return DEFAULT_CIPHER_PARAMS_FILE;
    }


    @Override
    public synchronized Cipher newLocalCipher(int opmode) throws IOException, GeneralSecurityException {
        final boolean init = !paramsFile.isFile();
        
        if (keySpec == null) {
            log.info("Retrieving local cipher key...");
            keySpec = getLocalKeySpec(init);
        }

        final SecretKeyFactory keyFactory = SecretKeyFactory.getInstance(getAlgorithm());
        final SecretKey key = keyFactory.generateSecret(keySpec);
        final Cipher cipher = Cipher.getInstance(getAlgorithm());

        if (init) {
            initializeCipher(cipher, opmode, key);
            saveParameters(cipher);
        }
        else {
           final AlgorithmParameters params = loadParameters();
           cipher.init(opmode, key, params);
        }
        return cipher;
    }

    AlgorithmParameters loadParameters() throws IOException, GeneralSecurityException {
        final AlgorithmParameters params = AlgorithmParameters.getInstance(getAlgorithm());
        final byte [] encodedParams = FileUtils.readFileToByteArray(paramsFile);
        params.init(encodedParams);
        return params;
    }
    
    void saveParameters(final Cipher cipher) throws IOException {
        final AlgorithmParameters params = cipher.getParameters();
        final byte[] encodedParams = params.getEncoded();
        FileUtils.writeByteArrayToFile(paramsFile, encodedParams);
    }
}