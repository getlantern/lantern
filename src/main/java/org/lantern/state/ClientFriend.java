package org.lantern.state;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonIgnoreProperties;


@JsonIgnoreProperties(ignoreUnknown = true)
public class ClientFriend implements Friend {

    private Long id;
    
    private String email;

    private String name = "";
    
    private String userEmail;

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

    public ClientFriend() {
    }

    public ClientFriend(String email) {
        this.email = email;
    }

    public ClientFriend(String email, Status status, String name,
            long nextQuery, Long lastUpdated) {
        this.email = email;
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
    
    @Override
    public long getNextQuery() {
        return nextQuery;
    }

    @Override
    public void setNextQuery(long nextQuery) {
        this.nextQuery = nextQuery;
    }

    @Override
    public void setPendingSubscriptionRequest(boolean pending) {
        pendingSubscriptionRequest = pending;
    }

    @Override
    public boolean isPendingSubscriptionRequest() {
        return pendingSubscriptionRequest;
    }

    @Override
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
        this.userEmail = email;
    }

    @Override
    public long getLastUpdated() {
        return this.lastUpdated;
    }

    @Override
    public void setLastUpdated(long lastUpdated) {
        this.lastUpdated = lastUpdated;
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
