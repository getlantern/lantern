package org.lantern.privacy; 

import java.security.GeneralSecurityException;

/* may be thrown if a Cipher is requested before proper user input has been collected */
public class UserInputRequiredException extends GeneralSecurityException {
    public UserInputRequiredException() { super(); }
    public UserInputRequiredException(String msg) { super(msg); }
    public UserInputRequiredException(String message, Throwable cause) { super(message, cause); }
    public UserInputRequiredException(Throwable cause) { super(cause); }
    
}
