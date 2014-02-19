package org.lantern;

import java.util.Collection;
import java.util.Collections;

import org.codehaus.jackson.annotate.JsonIgnoreProperties;

import com.google.common.base.Objects;


@JsonIgnoreProperties(ignoreUnknown=true)
public class S3Config {

    public static final String DEFAULT_CONTROLLER_ID = "lanternctrl1-2";
    
    private String controller = DEFAULT_CONTROLLER_ID;
    private int minpoll = 5;
    private int maxpoll = 15;
    private Collection<FallbackProxy> fallbacks = Collections.emptyList();

    public S3Config() {}

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
    

    public void setController(String controller) {
        this.controller = controller;
    }

    public void setMinpoll(int minpoll) {
        this.minpoll = minpoll;
    }

    public void setMaxpoll(int maxpoll) {
        this.maxpoll = maxpoll;
    }

    public void setFallbacks(Collection<FallbackProxy> fallbacks) {
        this.fallbacks = fallbacks;
    }

    @Override
    public int hashCode() {
        return Objects.hashCode(controller, fallbacks, minpoll, maxpoll);
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == null) {
           return false;
        }
        if (getClass() != obj.getClass()){
           return false;
        }
        final S3Config other = (S3Config) obj;
        return Objects.equal(this.controller, other.controller) &&
                Objects.equal(this.fallbacks, other.fallbacks) &&
                Objects.equal(this.minpoll, other.minpoll) &&
                Objects.equal(this.maxpoll, other.maxpoll);
    }
}
