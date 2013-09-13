package org.lantern.state;

/**
 * Defines the priority of UDP proxies versus TCP.
 */
public enum UDPProxyPriority {
    LOWER(-1), SAME(0), HIGHER(1);

    private final int multiplier;

    UDPProxyPriority(int multiplier) {
        this.multiplier = multiplier;
    }

    /**
     * <p>
     * Adjusts an existing comparison of two proxies to reflect this
     * {@link UDPProxyPriority}. The original result should be based on a
     * comparison that prioritizes TCP over UDP.
     * </p>
     * 
     * @param comparisonResult
     * @return the adjusted comparisonResult based on this priority
     */
    public int adjustComparisonResult(int comparisonResult) {
        return multiplier * comparisonResult;
    }
}
