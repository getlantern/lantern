package org.lantern;

import org.lantern.annotation.Keep;
import org.lantern.monitoring.Stats;
import org.lantern.monitoring.Stats.Counters;
import org.lantern.monitoring.Stats.Gauges;

@Keep
public class Country {

    private String code;
    private String name;
    private boolean censors;
    private Stats stats;

    public Country() {

    }

    public Country(final String code, final String name, final boolean cens) {
        this.code = code;
        this.name = name;
        this.censors = cens;
    }

    public void setCode(final String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public void setName(final String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public void setCensors(final boolean censors) {
        this.censors = censors;
    }

    public boolean isCensors() {
        return censors;
    }

    public void setStats(Stats stats) {
        this.stats = stats;
    }

    public Stats getStats() {
        return stats;
    }

    public Long getBps() {
        if (stats == null) {
            return null;
        }
        return stats.getGauge(Gauges.bpsGivenByPeer)
                + stats.getGauge(Gauges.bpsGotten);
    }

    public Long getBytesEver() {
        if (stats == null) {
            return null;
        }
        return stats.getCounter(Counters.bytesGivenByPeer)
                + stats.getCounter(Counters.bytesGotten);
    }

}
