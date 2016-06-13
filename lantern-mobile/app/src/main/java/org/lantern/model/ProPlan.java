package org.lantern.model;

import java.util.Locale;

public class ProPlan {

    private String plan;
    private String description;
    private String costStr;
    private Locale locale;
    private boolean bestValue;
    private long numYears;
    private long price;

    public ProPlan(String plan, String description, boolean bestValue, long numYears, long price) {
        this.plan = plan;
        this.description = description;
        this.bestValue = bestValue;
        this.numYears = numYears;
        this.price = price;
    }

    public Long numYears() {
        return numYears;
    }

    public void setLocale(Locale locale) {
        this.locale = locale;
    }

    public Locale getLocale() {
        return locale;
    }

    public Long getPrice() {
        return price;
    }

    public String getPlanId() {
        return plan;
    }

    public String getCostStr() {
        return this.costStr;
    }

    public void setCostStr(String costStr) {
        this.costStr = costStr;
    }

    public void setPrice(long price) {
        this.price = price;
    }
}
