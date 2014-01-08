package org.lantern.endpoints;

import java.io.IOException;

import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.JsonUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.messages.FriendResponse;
import org.lantern.oauth.OauthUtils;
import org.lantern.state.ClientFriend;
import org.lantern.state.Friend;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;

/**
 * API for accessing the remote friends endpoint on the controller.
 */
public class FriendApi {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final String BASE = 
        LanternClientConstants.CONTROLLER_URL + "/_ah/api/friend/v1/friend/";
    
    /**
     * We store this separately because it does internal caching that can
     * speed things up on subsequent calls, or so they say.
     */
    private final ObjectMapper mapper = new ObjectMapper();

    private final OauthUtils oauth;
    
    @Inject
    public FriendApi(final OauthUtils oauth) {
        this.oauth = oauth;
    }
    
    /**
     * This method lists all the entities inserted in datastore. It uses HTTP
     * GET method.
     * 
     * @return List of all entities persisted.
     * @throws IOException If there's an error making the call to the server.
     */
    public FriendResponse<ClientFriend[]> listFriends() throws IOException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return new FriendResponse(false, 0, null);
        }
        final String url = BASE + "list";
        final String json = this.oauth.getRequest(url);
        return FriendResponse.fromJson(json, ClientFriend[].class);
    }

    /**
     * This method gets the entity having primary key id. It uses HTTP GET
     * method.
     * 
     * @param id The primary key of the java bean.
     * @return The entity with primary key id.
     * @throws IOException If there's an error making the call to the server.
     */
    public FriendResponse<ClientFriend> getFriend(final long id) throws IOException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return null;
        }
        final String url = BASE+"get/"+id;
        final String json = this.oauth.getRequest(url);
        return FriendResponse.fromJson(json, ClientFriend.class);
    }

    /**
     * This inserts the entity into App Engine datastore. It uses HTTP POST
     * method.
     * 
     * @param task The entity to be inserted.
     * @return The inserted entity.
     * @throws IOException If there's an error making the call to the server.
     */
    public FriendResponse<ClientFriend> insertFriend(final ClientFriend friend)
            throws IOException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return new FriendResponse(true, 0, friend);
        }
        log.debug("Inserting friend: {}", friend);
        final String url = BASE+"insert";
        return post(url, friend);
    }

    /**
     * This method is used for updating a entity. It uses HTTP PUT method.
     * 
     * @param friend The entity to be updated.
     * @return The updated entity.
     * @throws IOException If there's an error making the call to the server.
     */
    public FriendResponse<ClientFriend> updateFriend(final ClientFriend friend) throws IOException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return new FriendResponse(true, 0, friend);
        }
        log.debug("Updating friend: {}", friend);
        final String url = BASE+"update";
        return post(url, friend);
    }

    private FriendResponse<ClientFriend> post(final String url, final Friend friend) 
            throws IOException {
        final String json = JsonUtils.jsonify(friend);
        final String content = this.oauth.postRequest(url, json);
        return FriendResponse.fromJson(content, ClientFriend.class);
    }

    /**
     * This method removes the entity with primary key id. It uses HTTP DELETE
     * method.
     * 
     * @param id The primary key of the entity to be deleted.
     * @return The deleted entity.
     * @throws IOException If there's an error making the call to the server.
     */
    public void removeFriend(final long id) throws IOException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return;
        }
        final String url = BASE+"remove/"+id;
        
        // The responses to this simply return no entity body (204 No Content).
        this.oauth.deleteRequest(url);
    }

}