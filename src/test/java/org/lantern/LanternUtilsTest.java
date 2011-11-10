package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.net.InetSocketAddress;
import java.util.Collection;

import org.jivesoftware.smack.XMPPConnection;
import org.junit.Test;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {
    
    private static Logger LOG = LoggerFactory.getLogger(LanternUtilsTest.class);
    
    @Test 
    public void testGoogleStunServers() throws Exception {
        String email = LanternUtils.getStringProperty("google.user");
        String pwd = LanternUtils.getStringProperty("google.pwd");
        final XMPPConnection conn = XmppUtils.persistentXmppConnection(
            email, pwd, "dfalj;", 2);
        
        final Collection<InetSocketAddress> servers = 
            XmppUtils.googleStunServers(conn);
        LOG.info("Retrieved {} STUN servers", servers.size());
        assertTrue(!servers.isEmpty());
    }
    
    @Test 
    public void testOtrMode() throws Exception {

        String email = LanternUtils.getStringProperty("google.user");
        String pwd = LanternUtils.getStringProperty("google.pwd");
        final XMPPConnection conn = XmppUtils.persistentXmppConnection(
            email, pwd, "jqiq", 2);
        final String activateResponse = LanternUtils.activateOtr(conn).toXML();
        LOG.info("Got response: {}", activateResponse);
        
        final String allOtr = XmppUtils.getOtr(conn).toXML();
        LOG.info("All OTR: {}", allOtr);
        
        assertTrue(
            allOtr.contains("lantern-controller@appspot.com\" value=\"enabled"));
    }
    

    @Test 
    public void testToHttpsCandidates() throws Exception {
        Collection<String> candidates = 
            LanternUtils.toHttpsCandidates("http://www.google.com");
        assertTrue(candidates.contains("www.google.com"));
        assertTrue(candidates.contains("*.google.com"));
        assertTrue(candidates.contains("www.*.com"));
        assertTrue(candidates.contains("www.google.*"));
        assertEquals(4, candidates.size());
        
        candidates = 
            LanternUtils.toHttpsCandidates("http://test.www.google.com");
        assertTrue(candidates.contains("test.www.google.com"));
        assertTrue(candidates.contains("*.www.google.com"));
        assertTrue(candidates.contains("*.google.com"));
        assertTrue(candidates.contains("test.*.google.com"));
        assertTrue(candidates.contains("test.www.*.com"));
        assertTrue(candidates.contains("test.www.google.*"));
        assertEquals(6, candidates.size());
        //assertTrue(candidates.contains("*.com"));
        //assertTrue(candidates.contains("*"));
    }
    
    @Test 
    public void testCensored() throws Exception {
        final boolean censored = CensoredUtils.isCensored();
        assertFalse("Censored?", censored);
        assertTrue(CensoredUtils.isExportRestricted("78.110.96.7")); // Syria
        
        assertTrue(CensoredUtils.isCensored("78.110.96.7")); // Syria
        assertFalse(CensoredUtils.isCensored("151.38.39.114")); // Italy
        assertFalse(CensoredUtils.isCensored("12.25.205.51")); // USA
        assertFalse(CensoredUtils.isCensored("200.21.225.82")); // Columbia
        assertTrue(CensoredUtils.isCensored("212.95.136.18")); // Iran
        
        assertTrue(CensoredUtils.isCensored("58.14.0.1")); // China.
        
        assertTrue(CensoredUtils.isCensored("190.6.64.1")); // Cuba" 
        assertTrue(CensoredUtils.isCensored("58.186.0.1")); // Vietnam
        assertTrue(CensoredUtils.isCensored("82.114.160.1")); // Yemen
        //assertTrue(CensoredUtils.isCensored("196.200.96.1")); // Eritrea
        assertTrue(CensoredUtils.isCensored("213.55.64.1")); // Ethiopia
        assertTrue(CensoredUtils.isCensored("203.81.64.1")); // Myanmar
        assertTrue(CensoredUtils.isCensored("77.69.128.1")); // Bahrain
        assertTrue(CensoredUtils.isCensored("62.3.0.1")); // Saudi Arabia
        assertTrue(CensoredUtils.isCensored("62.209.128.0")); // Uzbekistan
        assertTrue(CensoredUtils.isCensored("94.102.176.1")); // Turkmenistan
        assertTrue(CensoredUtils.isCensored("175.45.176.1")); // North Korea
    }

}
