package org.lantern;

import static org.junit.Assert.*;
import io.netty.handler.codec.http.DefaultHttpRequest;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpVersion;

import java.io.File;
import java.io.FileOutputStream;
import java.net.InetSocketAddress;
import java.util.Collection;
import java.util.concurrent.Callable;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.SASLAuthentication;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smackx.packet.VCard;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.oauth.LanternSaslGoogleOAuth2Mechanism;
import org.lantern.state.Model;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.hash.HashCode;
import com.google.common.hash.Hashing;
import com.google.common.io.Files;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {

    private static Logger LOG = LoggerFactory.getLogger(LanternUtilsTest.class);

    @BeforeClass
    public static void setup() throws Exception {
        LOG.debug("Setting up LanternUtilsTests...");
        SASLAuthentication.registerSASLMechanism("X-OAUTH2",
                LanternSaslGoogleOAuth2Mechanism.class);
        TestUtils.load(true);
        System.setProperty("javax.net.debug", "ssl");
    }
    
    @Test
    public void testExtractExecutableFromJarFile() throws Exception {
        final String path = "pt/flashlight";
        final File dir = new File(Files.createTempDir(), "/test/subdir");
        final File extracted = 
                LanternUtils.extractExecutableFromJar(path, dir);
        assertTrue(extracted.isFile());
        assertTrue(extracted.canExecute());
        
        HashCode oldHash = Files.hash(extracted, Hashing.sha256());
        
        final File extracted2 = 
                LanternUtils.extractExecutableFromJar(path, dir);
        
        HashCode newHash = Files.hash(extracted2, Hashing.sha256());
        
        assertEquals(extracted, extracted2);
        assertEquals(oldHash, newHash);
        assertTrue(extracted.canExecute());
        
        final FileOutputStream fos = new FileOutputStream(extracted, true);
        fos.write(1);
        fos.close();
        
        HashCode updatedHash = Files.hash(extracted, Hashing.sha256());
        
        assertNotEquals(updatedHash, newHash);
        
        final File extracted3 = 
                LanternUtils.extractExecutableFromJar(path, dir);
        
        assertEquals(extracted, extracted3);
        HashCode finalHash = Files.hash(extracted3, Hashing.sha256());
        
        assertEquals(oldHash, finalHash);
        assertTrue(extracted.canExecute());
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
        assertTrue(!LanternUtils.isAnonymizedGoogleTalkAddress(id));

        id = "2bgg8h04men25@public.talk.google.com";
        assertTrue(!LanternUtils.isAnonymizedGoogleTalkAddress(id));

        id = "testuser@gmail.com";
        assertTrue(LanternUtils.isAnonymizedGoogleTalkAddress(id));
    }

    @Test
    public void testVCard() throws Exception {
        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" Testing vcard");
                final XMPPConnection conn = TestUtils.xmppConnection();
                assertTrue(conn.isAuthenticated());
                final VCard vcard = XmppUtils.getVCard(conn, TestUtils.getUserName());
                assertTrue(vcard != null);
                final String full = vcard.getField("FN");
                assertTrue(StringUtils.isNotBlank(full));
                return null;
            } 
        });
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
        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" Testing STUN servers...");
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
                return null;
            } 
         });
    }

    @Test
    public void testOtrMode() throws Exception {
        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" Testing OTR mode...");
                final XMPPConnection conn = TestUtils.xmppConnection();
                final String activateResponse = LanternUtils.activateOtr(conn).toXML();
                LOG.debug("Got response: {}", activateResponse);

                final String allOtr = XmppUtils.getOtr(conn).toXML();
                LOG.debug("All OTR: {}", allOtr);

                assertTrue("Unexpected response: "+allOtr,
                    allOtr.contains("google:nosave"));
                return null;
            } 
        });
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
    public void testHostAndPortFrom() {
        HttpRequest request = new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, "http://www.google.com/humans.txt");
        String[] result = LanternUtils.hostAndPortFrom(request);
        assertEquals(result[0], "www.google.com");
        assertNull(result[1], null);
        request = new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, "http://www.google.com:443/humans.txt");
        result = LanternUtils.hostAndPortFrom(request);
        assertEquals(result[0], "www.google.com");
        assertEquals(result[1], "443");
    }

}
