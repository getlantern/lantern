package org.lantern.privacy;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;


public class UnencryptedFileService implements EncryptedFileService {

    @Override
    public void localDecryptedCopy(File encryptedSrc, File plainDest)
            throws GeneralSecurityException, IOException {

    }

    @Override
    public void localEncryptedCopy(File plainSrc, File encryptedDest)
            throws GeneralSecurityException, IOException {
    }

    @Override
    public OutputStream localEncryptOutputStream(File file) throws IOException,
            GeneralSecurityException {
        return new FileOutputStream(file);
    }

    @Override
    public OutputStream localEncryptOutputStream(OutputStream os)
            throws IOException, GeneralSecurityException {
        return os;
    }

    @Override
    public InputStream localDecryptInputStream(InputStream in)
            throws IOException, GeneralSecurityException {
        return in;
    }

    @Override
    public InputStream localDecryptInputStream(File file) throws IOException,
            GeneralSecurityException {
        return new FileInputStream(file);
    }

}
