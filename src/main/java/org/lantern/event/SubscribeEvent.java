package org.lantern.event;

public class SubscribeEvent {

    private final String email;

    public SubscribeEvent(String email) {
        this.email = email;
    }

    public String getEmail() {
        return email;
    }

}
