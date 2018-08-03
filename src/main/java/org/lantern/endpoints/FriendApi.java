package org.lantern.endpoints;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.lantern.JsonUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.messages.FriendResponse;
import org.lantern.oauth.OauthUtils;
import org.lantern.state.ClientFriend;
import org.lantern.state.Friend;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;

/**
 * API for accessing the remote friends endpoint on the controller.
 */
public class FriendApi {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final OauthUtils oauth;
    private final Model model;
    
    @Inject
    public FriendApi(OauthUtils oauth, Model model) {
        this.oauth = oauth;
        this.model = model;
    }
    
    /**
     * This method lists all the entities inserted in datastore. It uses HTTP
     * GET method.
     * 
     * @return List of all entities persisted.
     * @throws IOException If there's an error making the call to the server.
     * @throws CredentialException If the user's credentials are invalid.
     */
    public ClientFriend[] listFriends() throws IOException, CredentialException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return null;
        }
        final String url = baseUrl() + "list";
        final String json = this.oauth.getRequest(url);
        return processResponse(json, ClientFriend[].class);
    }

    /**
     * This method gets the entity having primary key id. It uses HTTP GET
     * method.
     * 
     * @param id The primary key of the java bean.
     * @return The entity with primary key id.
     * @throws IOException If there's an error making the call to the server.
     * @throws CredentialException If the user's credentials are invalid.
     */
    public ClientFriend getFriend(final long id) throws IOException, 
        CredentialException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return null;
        }
        final String url = baseUrl()+"get/"+id;
        final String json = this.oauth.getRequest(url);
        return processResponse(json, ClientFriend.class);
    }

    /**
     * This inserts the entity into App Engine datastore. It uses HTTP POST
     * method.
     * 
     * @param task The entity to be inserted.
     * @return The inserted entity.
     * @throws IOException If there's an error making the call to the server.
     * @throws CredentialException If the user's credentials are invalid.
     */
    public ClientFriend insertFriend(final ClientFriend friend)
            throws IOException, CredentialException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return friend;
        }
        log.debug("Inserting friend: {}", friend);
        final String url = baseUrl()+"insert";
        return post(url, friend);
    }

    /**
     * This method is used for updating a entity. It uses HTTP PUT method.
     * 
     * @param friend The entity to be updated.
     * @return The updated entity.
     * @throws IOException If there's an error making the call to the server.
     * @throws CredentialException If the user's credentials are invalid.
     */
    public ClientFriend updateFriend(final ClientFriend friend) 
            throws IOException, CredentialException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return friend;
        }
        log.debug("Updating friend: {}", friend);
        final String url = baseUrl()+"update";
        return post(url, friend);
    }

    private ClientFriend post(final String url, final Friend friend) 
            throws IOException, CredentialException {
        final String json = JsonUtils.jsonify(friend);
        final String content = this.oauth.postRequest(url, json);
        return processResponse(content, ClientFriend.class);
    }

    /**
     * This method removes the entity with primary key id. It uses HTTP DELETE
     * method.
     * 
     * @param id The primary key of the entity to be deleted.
     * @return The deleted entity.
     * @throws IOException If there's an error making the call to the server.
     * @throws CredentialException If the user's credentials are invalid.
     */
    public void removeFriend(final long id) throws IOException, 
        CredentialException {
        if (LanternUtils.isFallbackProxy()) {
            log.debug("Ignoring friends call from fallback");
            return;
        }
        final String url = baseUrl()+"remove/"+id;
        
        // The responses to this simply return no entity body (204 No Content).
        this.oauth.deleteRequest(url);
    }
    
    private String baseUrl() {
        return LanternClientConstants.CONTROLLER_URL + "/_ah/api/friend/v2/friend/";
    }
    
    private <P> P processResponse(String json, Class<P> payloadType)
            throws IOException {
        FriendResponse<P> resp = FriendResponse.fromJson(json, payloadType);
        if (!resp.isSuccess()) {
            throw new IOException(
                    "Request failed - maybe friending quota was exceeded?");
        }
        model.setRemainingFriendingQuota(resp.getRemainingFriendingQuota());
        Events.sync(SyncPath.FRIENDING_QUOTA, resp.getRemainingFriendingQuota());
        return resp.payload();
    }

}