package org.lantern.model;

public class Bandwidth {
    private Long quota;
    private Long remaining;

    public Bandwidth(Long quota, Long remaining) {
        this.quota = quota;
        this.remaining = remaining;
    }

    public Long getQuota() {
        return quota;
    }

    public Long getRemaining() {
        return remaining;
    }

}
