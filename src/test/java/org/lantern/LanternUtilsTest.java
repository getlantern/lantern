package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.security.Security;
import java.util.Arrays;
import java.util.Collection;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLSocket;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smackx.packet.VCard;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.state.Model;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for Lantern utilities.
 */
//@Ignore
public class LanternUtilsTest {

    private static Logger LOG = LoggerFactory.getLogger(LanternUtilsTest.class);

    private final String msg = "oh hi";

    private final AtomicReference<String> readOnServer =
        new AtomicReference<String>("");
    
    @BeforeClass
    public static void setup() throws Exception {
        TestUtils.load(true);
        System.setProperty("javax.net.debug", "ssl");
    }
    
    @Test 
    public void testGoogleTalkReachable() throws Exception {
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing gtalk reachability");
        assertTrue(LanternUtils.isGoogleTalkReachable());
    }

    @Test
    public void testGetTargetForPath() throws Exception {
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing getTarget");
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
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing jid");
        String id = "2bgg8h04men25@id.talk.google.com";
        assertTrue(!LanternUtils.isNotJid(id));

        id = "2bgg8h04men25@public.talk.google.com";
        assertTrue(!LanternUtils.isNotJid(id));

        id = "testuser@gmail.com";
        assertTrue(LanternUtils.isNotJid(id));
    }

    @Test
    public void testVCard() throws Exception {
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing vcard");
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
    public void testSSL() throws Exception {
        final LanternKeyStoreManager ksm = TestUtils.getKsm();
        System.setProperty("javax.net.debug", "ssl");
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        Launcher.configureCipherSuites();
        /*
        Security.addProvider(new BouncyCastleProvider());
        IceConfig.setCipherSuites(new String[] {
            //"TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
                Launcher.CIPHER_SUITE_LOW_BIT,
            //"SSL_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDHE_RSA_WITH_RC4_128_SHA"
        });
        */
        final XmppHandler xmpp = TestUtils.getXmppHandler();
        // We have to actually connect because the ID we use in the keystore
        // is our XMPP JID.
        xmpp.connect();

        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        // Since we're connecting to ourselves for testing, we need to add our
        // own key to the *trust store* from the key store.
        
        final LanternTrustStore ts = TestUtils.getTrustStore();
        LOG.warn("ADDING TO TS: "+LanternTrustStore.TRUSTSTORE_FILE);
        LOG.warn("KSM: "+ksm);
        LOG.warn("KSM KEYSTORE: "+ksm.KEYSTORE_FILE);
        ts.addBase64Cert(xmpp.getJid(), ksm.getBase64Cert(xmpp.getJid()));


        final SocketFactory clientFactory =
            TestUtils.getSocketsUtil().newTlsSocketFactory();
        final ServerSocketFactory serverFactory =
            TestUtils.getSocketsUtil().newTlsServerSocketFactory();

        final SocketAddress endpoint =
            new InetSocketAddress("127.0.0.1", LanternUtils.randomPort());

        final SSLServerSocket ss =
            (SSLServerSocket) serverFactory.createServerSocket();
        
        LOG.warn("SUPPORTED: "+Arrays.asList(ss.getSupportedCipherSuites()));
        ss.bind(endpoint);

        acceptIncoming(ss);
        Thread.sleep(400);

        final SSLSocket client = (SSLSocket) clientFactory.createSocket();
        LOG.warn("CLIENT SUPPORTED: "+Arrays.asList(client.getSupportedCipherSuites()));
        client.setSoTimeout(30000);
        client.connect(endpoint, 2000);

        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        Thread.sleep(20000);
        assertTrue(client.isConnected());

        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        synchronized (readOnServer) {
            final OutputStream os = client.getOutputStream();
            os.write(msg.getBytes("UTF-8"));
            os.close();
            readOnServer.wait(2000);
        }

        assertEquals(msg, readOnServer.get());
    }

    private void acceptIncoming(final SSLServerSocket ss) {
        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                try {

                    final SSLSocket sock = (SSLSocket) ss.accept();

                    LOG.debug("Incoming cipher list..." +
                        Arrays.asList(sock.getEnabledCipherSuites()));
                    final InputStream is = sock.getInputStream();
                    final int length = msg.getBytes("UTF-8").length;
                    final byte[] data = new byte[length];
                    int bytes = 0;
                    while (bytes < length) {
                        bytes += is.read(data, bytes, length - bytes);
                    }
                    final String read = new String(data, "UTF-8");
                    synchronized (readOnServer) {
                        readOnServer.set(read.trim());
                        readOnServer.notifyAll();
                    }
                } catch (final IOException e) {
                    e.printStackTrace();
                }
            }
        };
        final Thread t = new Thread(runner, "test-thread");
        t.setDaemon(true);
        t.start();
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
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing replaceInFile...");
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
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing STUN servers...");
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
        LOG.warn(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing OTR mode...");
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
