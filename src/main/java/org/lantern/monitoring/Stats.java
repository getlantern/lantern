package org.lantern.monitoring;

import java.util.HashMap;
import java.util.Map;

/**
 * Generic representation of statistics.
 */
public class Stats {
    private volatile Map<String, Long> counter = new HashMap<String, Long>();
    private volatile Map<String, Long> gauge = new HashMap<String, Long>();

    public Stats() {
    }

    public Map<String, Long> getCounter() {
        return counter;
    }

    public void setCounter(Map<String, Long> counter) {
        this.counter = counter;
    }

    public Map<String, Long> getGauge() {
        return gauge;
    }

    public void setGauge(Map<String, Long> gauge) {
        this.gauge = gauge;
    }

    public void setCounter(String name, long value) {
        counter.put(name, value);
    }

    public void setGauge(String name, long value) {
        gauge.put(name, value);
    }

}
