package org.lantern;

public class Country {

    private String code;
    private String name;

    public Country() {
        
    }
    
    public Country(final String code, final String name) {
        this.setCode(code);
        this.setName(name);
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

}
