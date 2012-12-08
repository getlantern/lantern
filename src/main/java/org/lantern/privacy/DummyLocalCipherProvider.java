package org.lantern.privacy;

import java.io.IOException;
import java.security.GeneralSecurityException;

import javax.crypto.Cipher;

public class DummyLocalCipherProvider implements LocalCipherProvider {

    @Override
    public Cipher newLocalCipher(int opmode) throws IOException,
            GeneralSecurityException {
        return Cipher.getInstance("AES/CBC/PKCS5Padding");
    }

    @Override
    public boolean requiresAdditionalUserInput() {
        return false;
    }

    @Override
    public void feedUserInput(char[] input, boolean init) throws IOException,
            GeneralSecurityException {
    }

    @Override
    public boolean isInitialized() {
        return true;
    }

    @Override
    public void reset() throws IOException {}

}
