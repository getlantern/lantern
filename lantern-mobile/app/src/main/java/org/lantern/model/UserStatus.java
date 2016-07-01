package org.lantern.model;

public class UserStatus {
    private boolean status;
    
    public UserStatus(boolean status) {
        this.status = status;
    }

    public boolean isActive() {
        return status;
    }
} 
