package org.lantern;

import org.jivesoftware.smack.packet.Presence;

public interface PresenceListener {

    void onPresence(String address, Presence presence);

    void removePresence(String address);

}
