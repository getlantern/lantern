package org.lantern;

public class Country {

    private String code;
    private String name;
    private boolean censoring;

    public Country() {
        
    }
    
    public Country(final String code, final String name) {
        this.code = code;
        this.name = name;
        this.censoring = LanternHub.censored().isCountryCodeCensored(code);
    }

    public Country(final com.maxmind.geoip.Country country) {
        this(country.getCode(), country.getName());
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

    public void setCensoring(final boolean censoring) {
        this.censoring = censoring;
    }

    public boolean isCensoring() {
        return censoring;
    }

}
