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

}