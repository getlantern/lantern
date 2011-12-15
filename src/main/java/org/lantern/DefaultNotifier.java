package org.lantern;

import java.util.ArrayList;
import java.util.Collection;

import org.jivesoftware.smack.packet.Presence;

public class DefaultNotifier implements Notifier {

    private final Collection<LanternUpdateListener> updateListeners =
        new ArrayList<LanternUpdateListener>();
    
    private final Collection<PresenceListener> presenceListeners =
        new ArrayList<PresenceListener>();
    
    @Override
    public void addUpdate(final LanternUpdate lanternUpdate) {
        synchronized (updateListeners) {
            for (final LanternUpdateListener lul : updateListeners) {
                lul.onUpdate(lanternUpdate);
            }
        }
    }

    @Override
    public void addUpdateListener(final LanternUpdateListener updateListener) {
        synchronized (updateListeners) {
            updateListeners.add(updateListener);
        }
    }

    @Override
    public void addPresence(final String address, final Presence presence) {
        synchronized (presenceListeners) {
            for (final PresenceListener lul : presenceListeners) {
                lul.onPresence(address, presence);
            }
        }
    }
    
    @Override
    public void removePresence(final String address) {
        synchronized (presenceListeners) {
            for (final PresenceListener lul : presenceListeners) {
                lul.removePresence(address);
            }
        }
    }

    @Override
    public void addPresenceListener(final PresenceListener presenceListener) {
        synchronized (presenceListeners) {
            presenceListeners.add(presenceListener);
        }
    }

}
