package org.lantern;

import java.util.Collection;

import org.jivesoftware.smack.packet.Presence;

import com.google.gson.Gson;

/**
 * Default class containing configuration settings and data.
 */
public class DefaultConfig implements Config {

    @Override
    public String roster() {
        final XmppHandler handler = LanternHub.xmppHandler();
        final Collection<Presence> presences = handler.getPresences();
        final Gson gson = new Gson();
        return gson.toJson(presences);
    }

}
