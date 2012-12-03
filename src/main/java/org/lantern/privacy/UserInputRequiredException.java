package org.lantern.privacy; 

import java.security.GeneralSecurityException;

/** 
 * May be thrown if a Cipher is requested before proper user input has been 
 * collected. 
 */
public class UserInputRequiredException extends GeneralSecurityException {
    private static final long serialVersionUID = 1196453121007591049L;
    
    public UserInputRequiredException() { super(); }
    public UserInputRequiredException(String msg) { super(msg); }
    public UserInputRequiredException(String message, Throwable cause) { super(message, cause); }
    public UserInputRequiredException(Throwable cause) { super(cause); }
    
}
