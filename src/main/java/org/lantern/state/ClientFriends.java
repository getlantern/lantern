package org.lantern.state;

import java.util.List;

import org.codehaus.jackson.annotate.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public class ClientFriends {

    private String url;
    
    private List<ClientFriend> items;
    
    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public List<ClientFriend> getItems() {
        return items;
    }

    public void setItems(List<ClientFriend> items) {
        this.items = items;
    }
}
