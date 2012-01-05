package org.lantern;

/**
 * Event for a change in authentication status.
 */
public class AuthenticationStatusEvent {

    private final AuthenticationStatus status;

    public AuthenticationStatusEvent(final AuthenticationStatus status) {
        this.status = status;
    }

    public AuthenticationStatus getStatus() {
        return status;
    }

}
