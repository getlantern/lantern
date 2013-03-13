package org.lantern.event;

public class InvitesChangedEvent {

    private final int newInvites;
    private final int oldInvites;

    public InvitesChangedEvent(int oldInvites, int newInvites) {
        this.oldInvites = oldInvites;
        this.newInvites = newInvites;
    }

    public int getOldInvites() {
        return oldInvites;
    }

    public int getNewInvites() {
        return newInvites;
    }

}
