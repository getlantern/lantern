package org.lantern;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.RosterPacket.ItemStatus;

public class LanternPresence {

    private boolean available;
    private boolean away;
    private String status;
    private boolean trusted;
    private String name;
    private String email;
    
    public LanternPresence(final RosterEntry entry) {
        this(false, false, extractStatus(entry),  
            extractName(entry), entry.getUser().trim());
    }

    public LanternPresence(final String email) {
        this(false, true, "", "", email);
    }
    
    public LanternPresence(final boolean available, final boolean away, 
        final String status, final String name, final String email) {
        this.available = available;
        this.away = away;
        this.status = status;
        this.name = name;
        this.email = email;
        this.trusted = extractTrusted(email);
    }
    

    public LanternPresence(final Presence pres) {
        this(pres.isAvailable(), false, pres.getStatus(), pres.getFrom(), 
            pres.getFrom());
    }

    private static String extractName(final RosterEntry entry) {
        final String entryName  = entry.getName();
        if (StringUtils.isBlank(entryName)) {
            return "";
        } else {
            return entryName;
        }
    }

    private static boolean extractTrusted(final String email) {
        return LanternHub.getTrustedContactsManager().isTrusted(email);
    }

    private static String extractStatus(final RosterEntry entry) {
        final ItemStatus stat = entry.getStatus();
        if (stat != null) {
            return stat.toString();
        } else {
            return "";
        }
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
