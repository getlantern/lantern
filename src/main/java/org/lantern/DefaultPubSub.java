package org.lantern;

import java.util.ArrayList;
import java.util.Collection;

import org.jivesoftware.smack.packet.Presence;

/**
 * This class allows callers to subscribe to events and be notified of them.
 */
public class DefaultPubSub implements PubSub {

    private final Collection<LanternUpdateListener> updateListeners =
        new ArrayList<LanternUpdateListener>();
    
    private final Collection<PresenceListener> presenceListeners =
        new ArrayList<PresenceListener>();
    
    
    private final Collection<ConnectivityListener> connectivityListeners =
        new ArrayList<ConnectivityListener>();

    private ConnectivityStatus connectivityStatus = 
        ConnectivityStatus.DISCONNECTED;
    
    @Override
    public void addConnectivityListener(final ConnectivityListener cl) {
        synchronized (connectivityListeners) {
            connectivityListeners.add(cl);
        }
    }
    
    @Override
    public void setConnectivityStatus(final ConnectivityStatus ct) {
        if (this.connectivityStatus == ct) {
            return;
        }
        this.connectivityStatus = ct;
        synchronized (connectivityListeners) {
            for (final ConnectivityListener cl : connectivityListeners) {
                cl.onConnectivityStateChanged(ct);
            }
        }
    }
    
    @Override
    public void addUpdate(final UpdateData lanternUpdate) {
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
            for (final PresenceListener pl : presenceListeners) {
                pl.onPresence(address, presence);
            }
        }
    }
    
    @Override
    public void removePresence(final String address) {
        synchronized (presenceListeners) {
            for (final PresenceListener pl : presenceListeners) {
                pl.removePresence(address);
            }
        }
    }

    @Override
    public void addPresenceListener(final PresenceListener presenceListener) {
        synchronized (presenceListeners) {
            presenceListeners.add(presenceListener);
        }
    }

    @Override
    public ConnectivityStatus getConnectivityStatus() {
        return this.connectivityStatus;
    }

}
