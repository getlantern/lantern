package org.lantern;

import java.util.Collection;


public class S3Config {

    private int serial_no;
    private String controller;
    private int minpoll;
    private int maxpoll;
    private Collection<FallbackProxy> fallbacks;

    public S3Config() {}

    public int getSerial_no() {
        return serial_no;
    }
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
}
