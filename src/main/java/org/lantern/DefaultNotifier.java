package org.lantern;

import java.util.ArrayList;
import java.util.Collection;

public class DefaultNotifier implements Notifier {

    private final Collection<LanternUpdateListener> updateListeners =
        new ArrayList<LanternUpdateListener>();
    
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

}
