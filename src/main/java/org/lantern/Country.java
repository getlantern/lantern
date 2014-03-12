package org.lantern;

import org.lantern.annotation.Keep;
import org.lantern.monitoring.Stats;

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

}
