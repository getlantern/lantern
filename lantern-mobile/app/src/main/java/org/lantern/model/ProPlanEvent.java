package org.lantern.model;

public class ProPlanEvent {

    private String plan;
    private String description;
    private boolean bestValue;
    private long numYears;
    private long price;

    public ProPlanEvent(String plan, String description, boolean bestValue, long numYears, long price) {
        this.plan = plan;
        this.description = description;
        this.bestValue = bestValue;
        this.numYears = numYears;
        this.price = price;
    }

    public Long numYears() {
        return numYears;
    }

    public Long getPrice() {
        return price;
    }

    public String getPlanId() {
        return plan;
    }
}
