package org.lantern;

import java.util.Collection;
import java.util.Collections;

import org.codehaus.jackson.annotate.JsonIgnoreProperties;


@JsonIgnoreProperties(ignoreUnknown=true)
public class S3Config {

    public static final String DEFAULT_CONTROLLER_ID = "lanternctrl";
    
    private int serial_no;
    private String controller = DEFAULT_CONTROLLER_ID;
    private int minpoll;
    private int maxpoll;
    private Collection<FallbackProxy> fallbacks = Collections.emptyList();

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
