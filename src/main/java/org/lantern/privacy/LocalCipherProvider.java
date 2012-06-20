package org.lantern.privacy; 

import java.io.IOException;
import java.security.GeneralSecurityException;

import javax.crypto.Cipher;


/**
 * interface to configure and obtain a Cipher for 
 * encrypting local data.  These may vary based on 
 * plaform, location, requirements of the user etc.
 * 
 */
public interface LocalCipherProvider {
    
    /**
     * Gives back a symmetric Cipher that can be used to 
     * encrypt/decrypt local data.
     *
     * @param opmode initalization mode, eg Cipher.ENCRYPT_MODE or Cipher.DECRYPT_MODE
     */
    public Cipher newLocalCipher(int opmode) throws IOException, GeneralSecurityException;

    /** 
     * returns true if the cipher cannot be built until
     * additional user input is provided via feedUserInput.
     *
     * If a cipher is requested while this is true, 
     * an exception will be thrown.
     */
    public boolean requiresAdditionalUserInput();
    
    /** 
     * feed in externally provided user input (eg password, phrase, etc)
     * has no effect if requiresAdditionalUserInput() is false
     * 
     * @param input the user provided key data
     * @param init if true, initialize the key with this input
     *             if false, validate the input against existing key data
     *
     */
    public void feedUserInput(char [] input, boolean init)
        throws IOException, GeneralSecurityException;

    /** 
     * returns true if the cipher has been initialized
     * with key data and initial parameters. 
     * ie a password has been set or 
     * a key generated and initial parameters saved by 
     * successfully building at least one cipher.
     */
    public boolean isInitialized();

    /** 
     * resets cipher internally.  Prior state information 
     * (initialization vectors, validators) will be destroyed. 
     * isInitialized will return false following this call.
     */
    public void reset() throws IOException;

}