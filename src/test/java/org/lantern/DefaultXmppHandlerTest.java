package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.Collection;
import java.util.HashSet;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for the XMPP handler.
 */
public class DefaultXmppHandlerTest {

    private static Logger LOG = 
        LoggerFactory.getLogger(DefaultXmppHandlerTest.class);
    
    /**
     * Make sure we're getting messages back from the controller.
     * 
     * @throws Exception If anything goes haywire.
     */
    @Test public void testControllerMessages() throws Exception {
        final String email = LanternHub.settings().getEmail();
        final String pwd = LanternHub.settings().getPassword();
        if (StringUtils.isBlank(email) || StringUtils.isBlank(pwd)) {
            LOG.info("user name and password not configured");
            return;
        }
        
        final Settings settings = LanternHub.settings();
        settings.setProxies(new HashSet<String>());
        final XmppHandler handler = 
            new DefaultXmppHandler(LanternUtils.randomPort(), 
                LanternUtils.randomPort());
        
        handler.connect();
        
        Collection<String> proxies = new HashSet<String>();
        
        int count = 0;
        while (proxies.isEmpty() && count < 100) {
            proxies = settings.getProxies();
            if (!proxies.isEmpty()) break;
            Thread.sleep(200);
            count++;
        }
        
        assertTrue(!proxies.isEmpty());
    }
}
