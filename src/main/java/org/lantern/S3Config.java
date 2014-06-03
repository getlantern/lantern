package org.lantern;

import java.util.Collection;
import java.util.Collections;

import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.lantern.proxy.FallbackProxy;

@JsonIgnoreProperties(ignoreUnknown=true)
public class S3Config {

    public static final String DEFAULT_CONTROLLER_ID = "lanternctrl1-2";
    
    private String controller = DEFAULT_CONTROLLER_ID;
    private int minpoll = 5;
    private int maxpoll = 15;
    private Collection<FallbackProxy> fallbacks = Collections.emptyList();
    
    /**
     * Milliseconds to wait before retrying disconnected signaling connections.
     */
    private long signalingRetryTime = 6000;
    
    /**
     * Get stats every minute.
     */
    private int statsGetInterval = 60;
    
    /**
     * Wait a bit before first posting stats, to give the system a 
     * chance to initialize metadata.
     */
    private int statsPostInterval = 5 * 60;
    
    public S3Config() {}

    public String getController() {
        return controller;
    }
    public int getMinpoll() {
        return minpoll;
    }
    public int getMaxpoll() {
        return maxpoll;
    }
    public Collection<FallbackProxy> getFallbacks() {
        return fallbacks;
    }

    public void setController(String controller) {
        this.controller = controller;
    }

    public void setMinpoll(int minpoll) {
        this.minpoll = minpoll;
    }

    public void setMaxpoll(int maxpoll) {
        this.maxpoll = maxpoll;
    }

    public void setFallbacks(Collection<FallbackProxy> fallbacks) {
        this.fallbacks = fallbacks;
    }

    public int getStatsGetInterval() {
        return statsGetInterval;
    }

    public void setStatsGetInterval(int statsGetInterval) {
        this.statsGetInterval = statsGetInterval;
    }

    public int getStatsPostInterval() {
        return statsPostInterval;
    }

    public void setStatsPostInterval(int statsPostInterval) {
        this.statsPostInterval = statsPostInterval;
    }

    public long getSignalingRetryTime() {
        return signalingRetryTime;
    }

    public void setSignalingRetryTime(long signalingRetryTime) {
        this.signalingRetryTime = signalingRetryTime;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((controller == null) ? 0 : controller.hashCode());
        result = prime * result
                + ((fallbacks == null) ? 0 : fallbacks.hashCode());
        result = prime * result + maxpoll;
        result = prime * result + minpoll;
        result = prime * result
                + (int) (signalingRetryTime ^ (signalingRetryTime >>> 32));
        result = prime * result + statsGetInterval;
        result = prime * result + statsPostInterval;
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        S3Config other = (S3Config) obj;
        if (controller == null) {
            if (other.controller != null)
                return false;
        } else if (!controller.equals(other.controller))
            return false;
        if (fallbacks == null) {
            if (other.fallbacks != null)
                return false;
        } else if (!fallbacks.equals(other.fallbacks))
            return false;
        if (maxpoll != other.maxpoll)
            return false;
        if (minpoll != other.minpoll)
            return false;
        if (signalingRetryTime != other.signalingRetryTime)
            return false;
        if (statsGetInterval != other.statsGetInterval)
            return false;
        if (statsPostInterval != other.statsPostInterval)
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "S3Config [controller=" + controller + ", minpoll=" + minpoll
                + ", maxpoll=" + maxpoll + ", fallbacks=" + fallbacks
                + ", signalingRetryTime=" + signalingRetryTime
                + ", statsGetInterval=" + statsGetInterval
                + ", statsPostInterval=" + statsPostInterval + "]";
    }

    
}
