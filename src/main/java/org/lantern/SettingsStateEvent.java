package org.lantern; 

/**
 * Event for a change in the state of the settings
 */
public class SettingsStateEvent {

    private final SettingsState state;

    public SettingsStateEvent(final SettingsState state) {
        this.state = new SettingsState(state);
    }

    public SettingsState getState() {
        return state;
    }

}