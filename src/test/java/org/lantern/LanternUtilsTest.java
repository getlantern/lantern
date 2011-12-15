package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.net.InetSocketAddress;
import java.util.Collection;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
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
    public void testReplaceInFile() throws Exception {
        final File temp = File.createTempFile(String.valueOf(hashCode()), "test");
        temp.deleteOnExit();
        final String data = "blah blah blah <true/> blah blah";
        FileUtils.write(temp, data, "UTF-8");
        LanternUtils.replaceInFile(temp, "<true/>", "<false/>");
        final String newFile = FileUtils.readFileToString(temp, "UTF-8");
        assertEquals("blah blah blah <false/> blah blah", newFile);
    }
    
    @Test 
    public void testGoogleStunServers() throws Exception {
        String email = LanternUtils.getStringProperty("google.user");
        String pwd = LanternUtils.getStringProperty("google.pwd");
        if (StringUtils.isBlank(email) || StringUtils.isBlank(pwd)) {
            LOG.info("user name and password not configured");
            return;
        }
        final XMPPConnection conn = XmppUtils.persistentXmppConnection(
            email, pwd, "dfalj;", 2);
        
        final Collection<InetSocketAddress> servers = 
            XmppUtils.googleStunServers(conn);
        LOG.info("Retrieved {} STUN servers", servers.size());
        assertTrue(!servers.isEmpty());
        
        final Roster roster = conn.getRoster();
        roster.addRosterListener(new RosterListener() {
            
            @Override
            public void entriesDeleted(final Collection<String> addresses) {
                LOG.info("Entries deleted");
            }
            @Override
            public void entriesUpdated(final Collection<String> addresses) {
                LOG.info("Entries updated: {}", addresses);
            }
            @Override
            public void presenceChanged(final Presence presence) {
                LOG.info("Processing presence changed: {}", presence);
            }
            @Override
            public void entriesAdded(final Collection<String> addresses) {
                LOG.info("Entries added: "+addresses);
                for (final String address : addresses) {
                    //presences.add(address);
                }
            }
        });
        
        //Thread.sleep(40000);
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
        final boolean censored = LanternHub.censored().isCensored();
        assertFalse("Censored?", censored);
        assertTrue(LanternHub.censored().isExportRestricted("78.110.96.7")); // Syria
        
        assertTrue(LanternHub.censored().isCensored("78.110.96.7")); // Syria
        assertFalse(LanternHub.censored().isCensored("151.38.39.114")); // Italy
        assertFalse(LanternHub.censored().isCensored("12.25.205.51")); // USA
        assertFalse(LanternHub.censored().isCensored("200.21.225.82")); // Columbia
        assertTrue(LanternHub.censored().isCensored("212.95.136.18")); // Iran
        
        assertTrue(LanternHub.censored().isCensored("58.14.0.1")); // China.
        
        assertTrue(LanternHub.censored().isCensored("190.6.64.1")); // Cuba" 
        assertTrue(LanternHub.censored().isCensored("58.186.0.1")); // Vietnam
        assertTrue(LanternHub.censored().isCensored("82.114.160.1")); // Yemen
        //assertTrue(CensoredUtils.isCensored("196.200.96.1")); // Eritrea
        assertTrue(LanternHub.censored().isCensored("213.55.64.1")); // Ethiopia
        assertTrue(LanternHub.censored().isCensored("203.81.64.1")); // Myanmar
        assertTrue(LanternHub.censored().isCensored("77.69.128.1")); // Bahrain
        assertTrue(LanternHub.censored().isCensored("62.3.0.1")); // Saudi Arabia
        assertTrue(LanternHub.censored().isCensored("62.209.128.0")); // Uzbekistan
        assertTrue(LanternHub.censored().isCensored("94.102.176.1")); // Turkmenistan
        assertTrue(LanternHub.censored().isCensored("175.45.176.1")); // North Korea
    }

}
