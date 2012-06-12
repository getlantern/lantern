package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.security.InvalidAlgorithmParameterException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.cert.PKIXParameters;
import java.security.cert.TrustAnchor;
import java.security.cert.X509Certificate;
import java.util.Arrays;
import java.util.Collection;
import java.util.Iterator;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLSocket;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
import org.junit.Test;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {
    
    private static Logger LOG = LoggerFactory.getLogger(LanternUtilsTest.class);
    
    private final String msg = "oh hi";
    
    private final AtomicReference<String> readOnServer = 
        new AtomicReference<String>("");
    
    @Test
    public void testSSL() throws Exception {
        IceConfig.setCipherSuites(new String[] {
            "TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
            //"SSL_RSA_WITH_RC4_128_SHA"
        });
        //System.setProperty("javax.net.debug", "ssl:record");
        //System.setProperty("javax.net.debug", "ssl:handshake");
        
        final LanternKeyStoreManager ksm = LanternHub.getKeyStoreManager();
        ksm.addBase64Cert(LanternUtils.getMacAddress(), ksm.getBase64Cert());
        
        final SocketFactory clientFactory = LanternUtils.newTlsSocketFactory();
        final ServerSocketFactory serverFactory = 
            LanternUtils.newTlsServerSocketFactory();
        
        final SocketAddress endpoint =
            new InetSocketAddress("127.0.0.1", LanternUtils.randomPort()); 
        
        final SSLServerSocket ss = 
            (SSLServerSocket) serverFactory.createServerSocket();
        ss.bind(endpoint);
        
        acceptIncoming(ss);
        Thread.sleep(400);
        
        final SSLSocket client = (SSLSocket) clientFactory.createSocket();
        
        client.connect(endpoint, 2000);
        
        assertTrue(client.isConnected());
        
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
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        };
        final Thread t = new Thread(runner, "test-thread");
        t.setDaemon(true);
        t.start();
    }

    @Test
    public void testRoster() throws Exception {
        System.setProperty("javax.net.debug", "ssl:record");
        System.setProperty("javax.net.debug", "ssl:handshake");
        try {
            // Load the JDK's cacerts keystore file
            //String filename = System.getProperty("java.home") + "/lib/security/cacerts".replace('/', File.separatorChar);
            //FileInputStream is = new FileInputStream(filename);
            KeyStore keystore = LanternHub.trustManager().getTruststore();//KeyStore.getInstance(KeyStore.getDefaultType());
            //String password = "changeit";
            //keystore.load(is, password.toCharArray());

            // This class retrieves the most-trusted CAs from the keystore
            PKIXParameters params = new PKIXParameters(keystore);

            // Get the set of trust anchors, which contain the most-trusted CA certificates
            Iterator it = params.getTrustAnchors().iterator();
            while( it.hasNext() ) {
                TrustAnchor ta = (TrustAnchor)it.next();
                // Get certificate
                X509Certificate cert = ta.getTrustedCert();
                //System.err.println(cert);
            }
        //} catch (CertificateException e) {
        } catch (KeyStoreException e) {
        //} catch (NoSuchAlgorithmException e) {
        } catch (InvalidAlgorithmParameterException e) {
        //} catch (IOException e) {
        } 
        
        //System.out.println(System.getProperty("javax.net.ssl.trustStore"));
        //System.setProperty("javax.net.ssl.trustStore",
        //    LanternHub.trustManager().getTruststorePath());
        
        LanternUtils.configureXmpp();
        final String email = LanternHub.settings().getEmail();
        final String pwd = LanternHub.settings().getPassword();
        if (StringUtils.isBlank(email) || StringUtils.isBlank(pwd)) {
            LOG.info("user name and password not configured");
            return;
        }
        
        // Just make sure no exceptions are thrown for now.
        LanternUtils.getRosterEntries(email, pwd, 1);
        
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
        final String email = LanternHub.settings().getEmail();
        final String pwd = LanternHub.settings().getPassword();
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
        final String email = LanternHub.settings().getEmail();
        final String pwd = LanternHub.settings().getPassword();
        if (StringUtils.isBlank(email) || StringUtils.isBlank(pwd)) {
            LOG.info("Not testing with no credentials");
            return;
        }
        final XMPPConnection conn = XmppUtils.persistentXmppConnection(
            email, pwd, "jqiq", 2);
        final String activateResponse = LanternUtils.activateOtr(conn).toXML();
        LOG.info("Got response: {}", activateResponse);
        
        final String allOtr = XmppUtils.getOtr(conn).toXML();
        LOG.info("All OTR: {}", allOtr);
        
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
