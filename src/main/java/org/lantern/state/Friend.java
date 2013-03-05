package org.lantern.state;

import org.lantern.LanternUtils;

public class Friend {

    private String email;
    
    private String name = "";
    
    public Friend() {
        
    }
    
    public Friend(String email) {
        this.setEmail(email);
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getPicture() {
        return LanternUtils.defaultPhotoUrl();
    }

    public void setPicture(String picture) {
    }

}
