package org.lantern;

import java.util.Set;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.packet.RosterPacket.ItemStatus;

public class LanternPresence {

    private boolean available;
    private boolean away;
    private String status;
    private boolean trusted;
    private String name;
    private String email;
    
    public LanternPresence(final RosterEntry entry) {
        this.available = false;
        final ItemStatus stat = entry.getStatus();
        if (stat != null) {
            this.status = stat.toString();
        } else {
            this.status = "";
        }
        
        final String entryName  = entry.getName();
        if (StringUtils.isBlank(entryName)) {
            this.name = "";
        } else {
            this.name = entryName;
        }
        this.email = entry.getUser().trim();
        this.trusted = LanternHub.getTrustedContactsManager().isTrusted(
            this.email);
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

    public void setName(final String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getEmail() {
        return email;
    }

    public boolean isInvited() {
        return LanternHub.settings().getInvited().contains(email);
    }
    
    @Override
    public String toString() {
        return "LanternPresence [available=" + available + ", away=" + away
                + ", status=" + status + ", trusted=" + trusted + ", name="
                + name + ", email=" + email + "]";
    }
}
