package org.lantern;

/**
 * Event thrown when the server tells gives us the status of whether or not
 * we're in the closed beta.
 */
public class ClosedBetaEvent {

    private final boolean inClosedBeta;
    private final String to;

    public ClosedBetaEvent(final String to, final boolean inClosedBeta) {
        this.to = to;
        this.inClosedBeta = inClosedBeta;
    }

    public boolean isInClosedBeta() {
        return inClosedBeta;
    }

    public String getTo() {
        return to;
    }
}
