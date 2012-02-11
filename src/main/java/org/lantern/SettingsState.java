package org.lantern;

/**
 * Class representing the state of settings.
 */
public class SettingsState {

    public enum State {
        CORRUPTED,
        SET,
        UNSET,
    }
    
    private State state = State.UNSET;
    
    private String message = "";
    
    public void setState(final State state) {
        this.state = state;
    }

    public State getState() {
        return state;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getMessage() {
        return message;
    }

    @Override
    public String toString() {
        return "SettingsState [state=" + state + ", message=" + message + "]";
    }
}
