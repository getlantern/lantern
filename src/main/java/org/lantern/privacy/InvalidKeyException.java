package org.lantern.privacy; 

import java.security.GeneralSecurityException;

/* may be thrown if the key is invalid or user provided incorrect password */
public class InvalidKeyException extends GeneralSecurityException {
    public InvalidKeyException() { super(); }
    public InvalidKeyException(String msg) { super(msg); }
    public InvalidKeyException(String message, Throwable cause) { super(message, cause); }
    public InvalidKeyException(Throwable cause) { super(cause); }
}
