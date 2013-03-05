package org.lantern.state;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.lantern.LanternUtils;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

public class Profile {
    
    private String id = "";
    private String email = "";
    private boolean verified_email = false;
    private String name = "";
    private String given_name = "";
    private String family_name = "";
    private String link = "";
    private String picture = "";
    private String gender = "";
    private String birthday = "";
    private String locale = "";
    private String hd = "";
    
    @JsonView({Run.class, Persistent.class})
    public String getEmail() {
        return email;
    }
    public void setEmail(String email) {
        this.email = email;
    }
    
    @JsonView({Persistent.class})
    public boolean isVerified_email() {
        return verified_email;
    }
    
    public void setVerified_email(boolean verified_email) {
        this.verified_email = verified_email;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }
    
    @JsonView({Persistent.class})
    public String getFamily_name() {
        return family_name;
    }
    public void setFamily_name(String family_name) {
        this.family_name = family_name;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getLink() {
        return link;
    }
    public void setLink(String link) {
        this.link = link;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getPicture() {
        return StringUtils.isBlank(picture) ? LanternUtils.defaultPhotoUrl() : this.picture;
    }
    public void setPicture(String picture) {
        this.picture = picture;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getGender() {
        return gender;
    }
    public void setGender(String gender) {
        this.gender = gender;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getBirthday() {
        return birthday;
    }
    public void setBirthday(String birthday) {
        this.birthday = birthday;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getLocale() {
        return locale;
    }
    public void setLocale(String locale) {
        this.locale = locale;
    }
    
    @JsonView({Persistent.class})
    public String getId() {
        return id;
    }
    public void setId(String id) {
        this.id = id;
    }
    @JsonView({Persistent.class})
    public String getGiven_name() {
        return given_name;
    }
    public void setGiven_name(String given_name) {
        this.given_name = given_name;
    }

    @JsonView({Persistent.class})
    public String getHd() {
        return hd;
    }

    public void setHd(String hd) {
        this.hd = hd;
    }
    
    
}
