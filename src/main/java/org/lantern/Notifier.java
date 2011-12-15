package org.lantern;

/**
 * Class that keeps track of listeners and notifying listeners for various
 * operations. Allows listeners to be more loosely coupled to classes 
 * generating events.
 */
public interface Notifier {

    void addUpdate(LanternUpdate lanternUpdate);
    
    void addUpdateListener(LanternUpdateListener updateListener);

}
