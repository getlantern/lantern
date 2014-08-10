package org.lantern.proxy.pt;

/**
 * Listener for Flashlight masquerade events.
 */
public interface MasqueradeListener {

    void onTestedAndVerifiedHost(String host);

}
