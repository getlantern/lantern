package org.lantern;

/**
 * Exception for when we're not in closed beta.
 */
public class NotInClosedBetaException extends Exception {

    /**
     * Generated.
     */
    private static final long serialVersionUID = 5717671520113126464L;
    
    public NotInClosedBetaException() {
        super();
    }
    
    public NotInClosedBetaException(final String msg) {
        super(msg);
    }

}
