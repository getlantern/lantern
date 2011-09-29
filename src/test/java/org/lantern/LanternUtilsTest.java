package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.Collection;
import java.util.Locale;
import java.util.ResourceBundle;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.provider.ProviderManager;
import org.junit.Test;
import org.lantern.xmpp.GenericIQProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {
    
    private static Logger LOG = LoggerFactory.getLogger(LanternUtilsTest.class);
    
    @Test public void testOtrMode() throws Exception {
        ProviderManager.getInstance().addIQProvider(
                "query", "google:shared-status", new GenericIQProvider());
        ProviderManager.getInstance().addIQProvider(
                "query", "google:nosave", new GenericIQProvider());
        ProviderManager.getInstance().addIQProvider(
                "query", "http://jabber.org/protocol/disco#info", new GenericIQProvider());

        String email = LanternUtils.getStringProperty("google.user");
        String pwd = LanternUtils.getStringProperty("google.pwd");
        final XMPPConnection conn = LanternUtils.persistentXmppConnection(
            email, pwd, "jqiq", 2);
        final String activateResponse = LanternUtils.activateOtr(conn).toXML();
        LOG.info("Got response: {}", activateResponse);
        
        final String allOtr = LanternUtils.getOtr(conn).toXML();
        LOG.info("All OTR: {}", allOtr);
        
        assertTrue(
            allOtr.contains("lantern-controller@appspot.com\" value=\"enabled"));
    }
    
    
    @Test 
    public void testI18n() throws Exception {
        final ResourceBundle rb = 
            Utf8ResourceBundle.getBundle("LanternResourceBundle", Locale.CHINESE);
        
        final String val =
            rb.getString("Are_you_sure_you_want_to_ignore_the_update?".substring(
                0, LanternConstants.I18N_KEY_LENGTH));
        System.out.println(val);
        //System.out.println(rb.getString("userComment"));
        assertTrue(StringUtils.isNotBlank(val));
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
    }

}
