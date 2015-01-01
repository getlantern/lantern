package org.lantern.multicast;

import org.codehaus.jackson.annotate.JsonIgnore;

/**
 * Multicast messages Lantern sends.
 */
public class MulticastMessage {
    
    
    private String type;
    private String endpoint;
    
    public static MulticastMessage newBye(final String endpoint) {
        return new MulticastMessage("bye", endpoint);
    }
    
    public static MulticastMessage newHello(final String endpoint) {
        return new MulticastMessage("hi", endpoint);
    }

    public MulticastMessage() {
    }
    
    private MulticastMessage(final String type, final String endpoint) {
        this.setType(type);
        this.setEndpoint(endpoint);
    }

    public String getType() {
        return type;
    }

    public String getEndpoint() {
        return endpoint;
    }
    
    @JsonIgnore
    public boolean isBye() {
        return getType().equalsIgnoreCase("bye");
    }

    public void setType(String type) {
        this.type = type;
    }

    public void setEndpoint(String endpoint) {
        this.endpoint = endpoint;
    }

}
