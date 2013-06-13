package org.lantern.state;

import java.util.Collection;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.lantern.annotation.Keep;

@Keep
public class Friends {

    private Map<String, Friend> currentMap = 
        new ConcurrentHashMap<String, Friend>();
    
    private Map<String, Friend> pendingMap = 
        new ConcurrentHashMap<String, Friend>();

    public Friends() {}
    
    public Collection<Friend> getCurrent() {
        return vals(currentMap);
    }

    public void setCurrent(final Collection<Friend> current) {
        populateMap(current, this.currentMap);
    }

    public Collection<Friend> getPending() {
        return vals(pendingMap);
    }

    public void setPending(final Collection<Friend> pending) {
        populateMap(pending, this.pendingMap);
    }

    public void addPending(final String email) {
        add(pendingMap, email);
    }
    
    private void add(final Map<String, Friend> map, final String email) {
        add(map, new Friend(email));
    }
    
    private void add(final Map<String, Friend> map, final Friend friend) {
        map.put(friend.getEmail(), friend);
    }

    public void addCurrent(final String email) {
        add(currentMap, email);
    }

    public void removePending(final String email) {
        pendingMap.remove(email);
    }
    
    public void removeCurrent(final String email) {
        currentMap.remove(email);
    }

    private Collection<Friend> vals(final Map<String, Friend> map) {
        synchronized (map) {
            return map.values();
        }
    }

    private void populateMap(final Collection<Friend> profiles, 
        final Map<String, Friend> map) {
        for (final Friend profile : profiles) {
            add(map, profile);
        }
    }

    public void clear() {
        this.currentMap.clear();
        this.pendingMap.clear();
    }

}
