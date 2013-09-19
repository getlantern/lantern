package org.lantern.endpoints;

import static org.junit.Assert.*;

import java.util.List;

import org.junit.Test;
import org.lantern.TestingUtils;
import org.lantern.endpoints.FriendApi;
import org.lantern.http.OauthUtils;
import org.lantern.state.ClientFriend;
import org.lantern.state.Friend;
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;

/**
 * Tests for the friends syncing REST API.
 */
public class FriendEndpointTest {

    @Test
    public void testFriendEndpiont() throws Exception {
        final HttpClientFactory httpClientFactory = 
                TestingUtils.newHttClientFactory();
        final Model model = TestingUtils.newModel();
        final OauthUtils utils = new OauthUtils(httpClientFactory, model);
        final FriendApi api = new FriendApi(utils);
        
        final ClientFriend friend = new ClientFriend();
        friend.setEmail("test@test.com");
        friend.setName("Tester");
        api.insertFriend(friend);
        
        final List<ClientFriend> friends = api.listFriends();
        
        for (final ClientFriend f : friends) {
            final Long id = f.getId();
            api.removeFriend(id);
        }
        
        final List<ClientFriend> postDelete = api.listFriends();
        
        assertEquals(0, postDelete.size());
        
        final Friend inserted = api.insertFriend(friend);
        
        final String updatedName = "brandnew@email.com";
        inserted.setEmail(updatedName);
        final Friend updated = api.updateFriend(inserted);
        
        assertEquals(updatedName, updated.getEmail());
        
        final List<ClientFriend> newList = api.listFriends();
        for (final ClientFriend f : newList) {
            assertEquals(updatedName, f.getEmail());
            
            final Long id = f.getId();
            final Friend get = api.getFriend(id);
            assertEquals(id, get.getId());
            
            api.removeFriend(id);
        }
        
        final List<ClientFriend> empty = api.listFriends();
        assertEquals(0, empty.size());
    }
}