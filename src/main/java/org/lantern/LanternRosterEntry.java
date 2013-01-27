package org.lantern;

import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.RosterPacket.ItemStatus;
import org.jivesoftware.smackx.packet.VCard;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternRosterEntry implements Comparable<LanternRosterEntry> {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private int index;
    private boolean available;
    private boolean away;
    private String statusMessage;
    private String subscriptionStatus;
    private String name;
    private String email;

    private VCard vcard;

    private final boolean autosub;

    private final String avatarUrlBase;
    private final Roster roster;

    public LanternRosterEntry(final Presence pres, final String avatarUrl,
            final Roster roster) {
        this(pres.isAvailable(), false, pres.getFrom(), pres.getFrom(), pres
                .getStatus(), false, avatarUrl, roster);
    }

    public LanternRosterEntry(final String email, final String avatarUrl,
            final Roster roster) {
        this(false, true, email, "", "", false, avatarUrl, roster);
    }

    public LanternRosterEntry(final RosterEntry entry, final String avatarUrl,
            final Roster roster) {
        this(false, false, entry.getUser(), entry.getName(),
                extractSubscriptionStatus(entry), entry.isAutosub(), avatarUrl,
                roster);
    }

    private LanternRosterEntry(final boolean available, final boolean away,
            final String email, final String name,
            final String subscriptionStatus, final boolean autosub,
            final String avatarUrlBase, final Roster roster) {
        this.available = available;
        this.away = away;
        this.avatarUrlBase = avatarUrlBase;
        this.roster = roster;
        if (StringUtils.isBlank(email)) {
            log.warn("No email address!!");
            throw new IllegalArgumentException("Blank email??");
        }
        this.email = XmppUtils.jidToUser(email);
        this.name = name == null ? "" : name;
        this.setSubscriptionStatus(subscriptionStatus == null ? ""
                : subscriptionStatus);
        this.statusMessage = "";
        this.autosub = autosub;
    }

    private static String extractSubscriptionStatus(final RosterEntry entry) {
        final ItemStatus stat = entry.getStatus();
        return extractSubscriptionStatus(stat);
    }

    private static String extractSubscriptionStatus(final ItemStatus stat) {
        if (stat != null) {
            return stat.toString();
        } else {
            return "";
        }
    }

    public String getPicture() {
        return avatarUrlBase + "?email=" + getEmail();
    }

    @JsonIgnore
    public boolean isAvailable() {
        return available;
    }

    public void setAvailable(boolean available) {
        this.available = available;
    }

    @JsonIgnore
    public boolean isAway() {
        return away;
    }

    public void setAway(boolean away) {
        this.away = away;
    }

    public String getStatusMessage() {
        return statusMessage;
    }

    public void setStatusMessage(final String status) {
        if (status != null) {
            this.statusMessage = status;
        }
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
        return this.roster.getInvited().contains(email);
    }

    @JsonIgnore
    public VCard getVcard() {
        return vcard;
    }

    public void setVcard(VCard vcard) {
        this.vcard = vcard;
    }

    @JsonIgnore
    public boolean isAutosub() {
        return autosub;
    }

    @JsonIgnore
    public String getSubscriptionStatus() {
        return subscriptionStatus;
    }

    public void setSubscriptionStatus(String subscriptionStatus) {
        this.subscriptionStatus = subscriptionStatus;
    }

    public int getIndex() {
        return index;
    }

    public void setIndex(int index) {
        this.index = index;
    }

    @Override
    public String toString() {
        return "LanternRosterEntry [available=" + available + ", status="
                + statusMessage + ", name=" + name + ", email=" + email
                + ", index=" + index + "]";
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((email == null) ? 0 : email.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        LanternRosterEntry other = (LanternRosterEntry) obj;
        if (email == null) {
            if (other.email != null)
                return false;
        } else if (!email.equals(other.email))
            return false;
        return true;
    }

    @Override
    public int compareTo(final LanternRosterEntry lre) {
        final int scores = lre.getName().compareTo(name);

        // If they have the same name, compare by their e-mails. Otherwise
        // any entries with the same name will get consolidated.
        if (scores == 0) {
            return this.email.compareToIgnoreCase(lre.getEmail());
        } else {
            return -scores;
        }
    }
}
