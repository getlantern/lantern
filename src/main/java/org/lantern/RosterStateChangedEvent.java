package org.lantern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Event for when the state of the roster has changed.
 */
public class RosterStateChangedEvent {

    private static final Logger LOG = 
        LoggerFactory.getLogger(RosterStateChangedEvent.class);
    
    public RosterStateChangedEvent() {
        LOG.info("Creating new event!");
    }
}
