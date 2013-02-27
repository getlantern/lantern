package org.lantern;

import static org.junit.Assert.assertEquals;

import java.util.HashMap;
import java.util.Map;

import org.junit.Test;
import org.lantern.http.GoogleOauth2CallbackServlet;
import org.lantern.util.HttpClientFactory;

public class GoogleOauth2CallbackServletTest {


    @Test
    public void testGoogleApis() throws Exception {
        final HttpClientFactory client = TestUtils.getHttpClientFactory();
        final GoogleOauth2CallbackServlet servlet = 
            new GoogleOauth2CallbackServlet(null, null, null, null, null, 
                null, client);
        
        final Map<String, String> allToks = new HashMap<String, String>();
        allToks.put("access_token", "invalidcode");
        final int code = servlet.fetchEmail(allToks, client.newClient());
        
        // Expected to be unauthorized with a bogus token -- we want to 
        // make sure it gets there.
        assertEquals(401, code);
    }
}
