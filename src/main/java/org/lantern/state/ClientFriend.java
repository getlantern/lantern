package org.lantern.state;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.lantern.state.Friend.SuggestionReason;

public class ClientFriend implements Friend {

    private Long id;
    
    private String email;

    private String name = "";
    
    private String userEmail = "";

    private Status status = Status.pending;

    /**
     * The next time, in milliseconds since epoch, that we will ask the user
     * about this friend, assuming status=requested.
     */
    private long nextQuery;

    /**
     * Whether or not an XMPP subscription request from this user is pending.
     */
    private boolean pendingSubscriptionRequest;

    private Long lastUpdated = System.currentTimeMillis();
    
    private boolean loggedIn;
    
    private org.jivesoftware.smack.packet.Presence.Mode mode;
    
    private boolean freeToFriend = false;
    
    private SuggestionReason reason;

    public ClientFriend() {
    }

    public ClientFriend(final String email) {
        this.email = email.toLowerCase();
    }

    public ClientFriend(String email, Status status, String name,
            long nextQuery, Long lastUpdated) {
        this.email = email.toLowerCase();
        this.status = status;
        this.name = name;
        this.nextQuery = nextQuery;
        this.lastUpdated = lastUpdated;
    }

    @Override
    public String getEmail() {
        return email;
    }

    @Override
    public void setEmail(String email) {
        this.email = email;
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public void setName(String name) {
        this.name = name;
    }
    
    @Override
    public Status getStatus() {
        return status;
    }

    @Override
    public void setStatus(Status status) {
        this.status = status;
    }

    public void setPendingSubscriptionRequest(boolean pending) {
        pendingSubscriptionRequest = pending;
    }

    public boolean isPendingSubscriptionRequest() {
        return pendingSubscriptionRequest;
    }

    @JsonIgnore
    public boolean shouldNotifyAgain() {
        if (status == Status.pending) {
            long now = System.currentTimeMillis();
            return nextQuery < now;
        }
        return false;
    }

    @Override
    public Long getId() {
        return id;
    }

    @Override
    public void setId(Long id) {
        this.id = id;
    }

    @Override
    public String getUserEmail() {
        return this.userEmail;
    }

    @Override
    public void setUserEmail(final String email) {
        this.userEmail = email.toLowerCase();
    }

    @Override
    public long getLastUpdated() {
        return this.lastUpdated;
    }

    @Override
    public void setLastUpdated(long lastUpdated) {
        this.lastUpdated = lastUpdated;
    }
    
    public void setNextQuery(final long nextQuery) {
        this.nextQuery = nextQuery;
    }
    
    /**
     * Whether or not this peer is online in the sense of logged in to the 
     * XMPP server.
     * 
     * @return Whether the user is logged in to the XMPP server.
     */
    public boolean isLoggedIn() {
        return loggedIn;
    }

    /**
     * Sets whether or not this peer is online in the sense of logged in to the 
     * XMPP server.
     * 
     * @param loggedIn Whether the user is logged in to the XMPP server.
     */
    public void setLoggedIn(final boolean loggedIn) {
        this.loggedIn = loggedIn;
    }

    /**
     * Gets the users presence mode, such as available, away, dnd, etc.
     * 
     * @return The user's presence mode.
     */
    public org.jivesoftware.smack.packet.Presence.Mode getMode() {
        return mode;
    }

    /**
     * Sets the users presence mode, such as available, away, dnd, etc.
     * 
     * @param mode The user's presence mode.
     */
    public void setMode(final org.jivesoftware.smack.packet.Presence.Mode mode) {
        this.mode = mode;
    }
    
    @Override
    public void setFreeToFriend(boolean freeToFriend) {
        this.freeToFriend = freeToFriend;
    }
    
    @Override
    public boolean isFreeToFriend() {
        return this.freeToFriend;
    }
    
    @Override
    public SuggestionReason getReason() {
        return reason;
    }

    @Override
    public void setReason(SuggestionReason reason) {
        this.reason = reason;
    }
    
    @Override
    public String toString() {
        return "ClientFriend [email=" + email + ", name=" + name
                + ", userEmail=" + userEmail + ", status=" + status
                + ", nextQuery=" + nextQuery + ", pendingSubscriptionRequest="
                + pendingSubscriptionRequest + ", lastUpdated=" + lastUpdated
                + "]";
    }
}
