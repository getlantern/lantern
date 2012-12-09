package org.lantern;

public class Country {

    private String code;
    private String name;
    private boolean censoring;

    public Country() {
        
    }
    
    public Country(final String code, final String name, final boolean cens) {
        this.code = code;
        this.name = name;
        this.censoring = cens;
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
