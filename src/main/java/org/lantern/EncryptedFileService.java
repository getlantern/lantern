package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;

public interface EncryptedFileService {

    void localDecryptedCopy(File encryptedSrc, File plainDest)
            throws GeneralSecurityException, IOException;

    void localEncryptedCopy(File plainSrc, File encryptedDest)
            throws GeneralSecurityException, IOException;

    OutputStream localEncryptOutputStream(File file) throws IOException,
            GeneralSecurityException;

    OutputStream localEncryptOutputStream(OutputStream os) throws IOException,
            GeneralSecurityException;

    InputStream localDecryptInputStream(InputStream in) throws IOException,
            GeneralSecurityException;

    InputStream localDecryptInputStream(File file) throws IOException,
            GeneralSecurityException;

}
