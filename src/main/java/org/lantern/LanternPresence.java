package org.lantern;

import org.jivesoftware.smack.packet.Presence;

public class LanternPresence {

    private boolean available;
    private boolean away;
    private String status;
    private boolean trusted;

    public LanternPresence(final Presence presence) {
        this.available = presence.isAvailable();
        this.away = presence.isAway();
        this.status = presence.getStatus();
        this.setTrusted(LanternHub.getTrustedContactsManager().isTrusted(
            LanternUtils.jidToEmail(presence.getFrom())));
    }

    public boolean isAvailable() {
        return available;
    }

    public void setAvailable(boolean available) {
        this.available = available;
    }

    public boolean isAway() {
        return away;
    }

    public void setAway(boolean away) {
        this.away = away;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public void setTrusted(boolean trusted) {
        this.trusted = trusted;
    }

    public boolean isTrusted() {
        return trusted;
    }
}
