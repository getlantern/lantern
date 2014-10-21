package org.lantern;

import java.util.Collection;

public interface RosterHandler {

    void onRoster(XmppHandler xmppHandler);

    void reset();

    boolean autoAcceptSubscription(String from);

    LanternRosterEntry getRosterEntry(String jid);

    Collection<LanternRosterEntry> getEntries();

}
