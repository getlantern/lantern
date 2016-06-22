package org.lantern.model;

import android.util.Log;

import java.util.Currency;
import java.util.Locale;

public class ProPlan {

    private static final String TAG = "ProPlan";

    private String plan;
    private String description;
    private String currencyCode;
    private String tag;
    private String costStr;
    private Locale locale;
    private String symbol;
    private boolean bestValue;
    private long numYears;
    private long price;

    private static final String PLAN_COST = "%1$s%2$d (%3$s)";
    private static final String PRO_ONE_YEAR = "Lantern Pro 1 Year Subscription"; 
    private static final String PRO_TWO_YEAR = "Lantern Pro 2 Year Subscription";
    private static final String defaultCurrencyCode = "usd";

    public ProPlan(String plan, String description, String currencyCode, 
            boolean bestValue, long numYears, long price) {

        this.plan = plan;
        this.description = description;
        this.currencyCode = currencyCode;
        this.bestValue = bestValue;
        this.numYears = numYears;
        this.price = price;

        if (numYears == 1) {
            this.tag = PRO_ONE_YEAR;
        } else {
            this.tag = PRO_TWO_YEAR;
        }

        formatCost();
    }

    public void setCurrency(String currencyCode) {

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

    public String getDescription() {
        return description;
    }

    public String getCostStr() {
        return costStr;
    }

    public String getTag() {
        return tag;
    }

    public String getCurrency() {
        return currencyCode;
    }

    public String getSymbol() {
        return symbol;
    }

    private void formatCost() {
        Currency currency = Currency.getInstance(currencyCode);
        if (currency == null) {
            Log.e(TAG, "Invalid currency: " + currencyCode);
            currency = Currency.getInstance(defaultCurrencyCode);
        }
        long fmtPrice = price/100;

        this.symbol = currency.getSymbol();
        this.costStr = String.format(PLAN_COST, symbol, fmtPrice, currency.getCurrencyCode().toUpperCase());
    }

    public void setPrice(long price) {
        this.price = price;
    }
}
