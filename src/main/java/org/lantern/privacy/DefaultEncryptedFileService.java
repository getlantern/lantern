package org.lantern.privacy;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;

import javax.crypto.Cipher;
import javax.crypto.CipherInputStream;
import javax.crypto.CipherOutputStream;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class DefaultEncryptedFileService implements EncryptedFileService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final LocalCipherProvider localCipherProvider;

    @Inject
    public DefaultEncryptedFileService(
        final LocalCipherProvider localCipherProvider) {
        this.localCipherProvider = localCipherProvider;
    }
    
    @Override
    public InputStream localDecryptInputStream(final InputStream in) 
        throws IOException, GeneralSecurityException {
        final Cipher cipher = 
            this.localCipherProvider.newLocalCipher(Cipher.DECRYPT_MODE);
        return new CipherInputStream(in, cipher);
    }
    
    @Override
    public InputStream localDecryptInputStream(final File file) 
        throws IOException, GeneralSecurityException {
        checkFile(file);
        return localDecryptInputStream(new FileInputStream(file));
    }
    
    @Override
    public OutputStream localEncryptOutputStream(final OutputStream os)
        throws IOException, GeneralSecurityException {
        final Cipher cipher = 
            this.localCipherProvider.newLocalCipher(Cipher.ENCRYPT_MODE);
        return new CipherOutputStream(os, cipher);
    }
    
    @Override
    public OutputStream localEncryptOutputStream(final File file) 
        throws IOException, GeneralSecurityException {
        checkFile(file);
        return localEncryptOutputStream(new FileOutputStream(file));
    }
    
    private void checkFile(final File file) {
        final File dir = file.getParentFile();
        if (!dir.isDirectory()) {
            log.error("No parent directory at: {}", dir);
            if (!dir.mkdirs()) {
                log.error("Could not make directory for parent: {}", dir);
            }
        }
    }

    /** 
     * output an encrypted copy of the plaintext file given in the 
     * dest file given. 
     * 
     * @param plainSrc a plaintext source File to copy
     * @param encryptedDest a destination file to write an encrypted copy of 
     * plainSrc to
     */
    @Override
    public void localEncryptedCopy(final File plainSrc, 
        final File encryptedDest)
        throws GeneralSecurityException, IOException {
        if (plainSrc.equals(encryptedDest)) {
            throw new IOException("Source and dest cannot be the same file.");
        }
        
        InputStream in = null;
        OutputStream out = null;
        try {
            in = new FileInputStream(plainSrc);
            out = localEncryptOutputStream(encryptedDest);
            IOUtils.copy(in, out);
        } finally {
            IOUtils.closeQuietly(in);
            IOUtils.closeQuietly(out);
        }
    }

    /**
     * output a decrypted copy of the encrypted file given in the 
     * dest file given. 
     * 
     * @param encryptedSrc an encrypted source file to copy
     * @param plainDest a destination file to write a decrypted copy of 
     * encryptedSrc to
     * 
     */
    @Override
    public void localDecryptedCopy(final File encryptedSrc, 
        final File plainDest)
        throws GeneralSecurityException, IOException {
        if (encryptedSrc.equals(plainDest)) {
            throw new IOException("Source and dest cannot be the same file.");
        }
        InputStream in = null;
        OutputStream out = null;
        try {
            in = localDecryptInputStream(encryptedSrc);
            out = new FileOutputStream(plainDest);
            IOUtils.copy(in, out);
        } finally {
            IOUtils.closeQuietly(in);
            IOUtils.closeQuietly(out);
        }    
    }
}
