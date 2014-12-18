package org.lantern;

/**
 * An exception experienced during initialization.
 */
public class InitException extends Exception {

    private static final long serialVersionUID = -459493985161165412L;
    
    public InitException(String msg) {
        super(msg);
    }

}
