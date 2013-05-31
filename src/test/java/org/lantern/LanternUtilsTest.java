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
import org.jivesoftware.smackx.packet.VCard;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.state.Model;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for Lantern utilities.
 */
//@Ignore
public class LanternUtilsTest {

    private static Logger LOG = LoggerFactory.getLogger(LanternUtilsTest.class);

    @BeforeClass
    public static void setup() throws Exception {
        LOG.debug("Setting up LanternUtilsTests...");
        TestUtils.load(true);
        System.setProperty("javax.net.debug", "ssl");
    }
    
    @Test
    public void testGetTargetForPath() throws Exception {
        final Model model = TestUtils.getModel();

        assertFalse(model.isLaunchd());
        Object obj = LanternUtils.getTargetForPath(model,
            "/version/installed/major");

        assertEquals(model.getVersion().getInstalled(), obj);
        obj = LanternUtils.getTargetForPath(model, "/settings/mode");
        assertEquals(model.getSettings(), obj);
    }

    @Test
    public void testIsJid() throws Exception {
        String id = "2bgg8h04men25@id.talk.google.com";
        assertTrue(!LanternUtils.isNotJid(id));

        id = "2bgg8h04men25@public.talk.google.com";
        assertTrue(!LanternUtils.isNotJid(id));

        id = "testuser@gmail.com";
        assertTrue(LanternUtils.isNotJid(id));
    }

    @Test
    public void testVCard() throws Exception {
        LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing vcard");
        final XMPPConnection conn = TestUtils.xmppConnection();
        assertTrue(conn.isAuthenticated());
        final VCard vcard = XmppUtils.getVCard(conn, TestUtils.getUserName());
        assertTrue(vcard != null);
        final String full = vcard.getField("FN");
        assertTrue(StringUtils.isNotBlank(full));

        // The photo might be null with test accounts!
        //final byte[] photo = vcard.getAvatar();
        //assertTrue(photo != null);
        //assertTrue(!(photo.length == 0));
    }

    @Test
    public void testToTypes() throws Exception {
        assertEquals(String.class, LanternUtils.toTyped("33fga").getClass());
        assertEquals(Integer.class, LanternUtils.toTyped("21314").getClass());
        assertEquals(String.class, LanternUtils.toTyped("2a3b").getClass());

        assertEquals(Boolean.class, LanternUtils.toTyped("true").getClass());
        assertEquals(Boolean.class, LanternUtils.toTyped("false").getClass());
        assertEquals(Boolean.class, LanternUtils.toTyped("on").getClass());
        assertEquals(Boolean.class, LanternUtils.toTyped("off").getClass());

        assertEquals(String.class, LanternUtils.toTyped("2222a").getClass());
    }

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
        LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing STUN servers...");
        final XMPPConnection conn = TestUtils.xmppConnection();

        final Collection<InetSocketAddress> servers =
            XmppUtils.googleStunServers(conn);
        LOG.debug("Retrieved {} STUN servers", servers.size());
        assertTrue(!servers.isEmpty());

        final Roster roster = conn.getRoster();
        roster.addRosterListener(new RosterListener() {

            @Override
            public void entriesDeleted(final Collection<String> addresses) {
                LOG.debug("Entries deleted");
            }
            @Override
            public void entriesUpdated(final Collection<String> addresses) {
                LOG.debug("Entries updated: {}", addresses);
            }
            @Override
            public void presenceChanged(final Presence presence) {
                LOG.debug("Processing presence changed: {}", presence);
            }
            @Override
            public void entriesAdded(final Collection<String> addresses) {
                LOG.debug("Entries added: "+addresses);
                for (final String address : addresses) {
                    //presences.add(address);
                }
            }
        });

        //Thread.sleep(40000);
    }

    @Test
    public void testOtrMode() throws Exception {
        LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing OTR mode...");
        //System.setProperty("javax.net.debug", "ssl");
        /*
        final File certsFile = new File("src/test/resources/cacerts");
        if (!certsFile.isFile()) {
            throw new IllegalStateException("COULD NOT FIND CACERTS!!");
        }
        System.setProperty("javax.net.ssl.trustStore", certsFile.getCanonicalPath());
        */
        final XMPPConnection conn = TestUtils.xmppConnection();
        //System.setProperty("javax.net.ssl.trustStore", certsFile.getCanonicalPath());
        final String activateResponse = LanternUtils.activateOtr(conn).toXML();
        LOG.debug("Got response: {}", activateResponse);
        
        final String allOtr = XmppUtils.getOtr(conn).toXML();
        LOG.debug("All OTR: {}", allOtr);
        
        assertTrue("Unexpected response: "+allOtr, 
            allOtr.contains("google:nosave"));
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
    
}
