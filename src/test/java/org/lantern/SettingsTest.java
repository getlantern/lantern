package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class SettingsTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void testSettingsUpdate() throws Exception {
        final File plist = plist();
        final File settingsFile = settingsFile();
        
        final SettingsIo io = new SettingsIo(plist, settingsFile);
        final Settings settings = io.read();
        
        final Map<String, Object> update = new HashMap<String, Object>();
        update.put("system", "{'systemProxy' : false}}");
        
        //io.apply(update);
        
        
    }
    
    @Test
    public void testSettings() throws Exception {
        final File plist = plist();
        final File settingsFile = settingsFile();
        
        final SettingsIo io = new SettingsIo(plist, settingsFile);
        final Settings settings = io.read();
        assertEquals(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT, 
            settings.getSystem().getPort());
        
        final int port = 2830;
        settings.getSystem().setPort(port);
        io.write(settings);
        
        final Settings read = io.read();
        assertEquals(port, read.getSystem().getPort());
        
        final Whitelist whitelist = read.getWhitelist();
        
        
        assertTrue(whitelist.isWhitelisted("www.facebook.com:443"));
        assertTrue(whitelist.isWhitelisted("avaaz.org"));
        assertTrue(whitelist.isWhitelisted("getlantern.org"));
        assertFalse(whitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertFalse(whitelist.isWhitelisted("http://www.nytimes.com/"));
        assertTrue(whitelist.isWhitelisted("www.facebook.com:443"));
        assertTrue(whitelist.isWhitelisted("https://s-static.ak.facebook.com"));
        
        whitelist.addEntry("nytimes.com");
        whitelist.removeEntry("avaaz.org");
        whitelist.removeEntry("getlantern.org");

        io.write(read);
        final Settings read2 = io.read();
        final Whitelist readWhitelist = read2.getWhitelist();
        
        assertTrue(readWhitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertTrue(readWhitelist.isWhitelisted("http://www.nytimes.com/"));
        assertFalse(whitelist.isWhitelisted("avaaz.org"));
        assertTrue(whitelist.isWhitelisted("getlantern.org"));
    }
    

    @Test
    public void testStartAtLogin() throws Exception {
        if (!LanternConstants.LAUNCHD_PLIST.isFile()) {
            log.info("No plist file - not installed or on different OS?");
            return;
        }
        final Settings settings = LanternHub.settings();
        final File temp = plist();
        final File settingsFile = settingsFile();
        FileUtils.copyFile(LanternConstants.LAUNCHD_PLIST, temp);
        final String cur = FileUtils.readFileToString(temp, "UTF-8");
        
        assertTrue(cur.contains("<true/>") || cur.contains("<false/>"));
        final SettingsIo ss = new SettingsIo(temp, settingsFile);
        final SettingsChangeImplementor implementor = 
            new SettingsChangeImplementor(temp);
        if (cur.contains("<true/>")) {
            assertFalse(cur.contains("<false/>"));
            //Configurator.setStartAtLogin(temp, false);
            settings.getSystem().setStartAtLogin(false);
            implementor.setStartAtLogin(false);
            ss.write(settings);
            final String newFile = FileUtils.readFileToString(temp, "UTF-8");
            assertTrue(newFile.contains("<false/>"));
        } else if (cur.contains("<false/>")) {
            assertFalse(cur.contains("<true/>"));
            //Configurator.setStartAtLogin(temp, true);
            settings.getSystem().setStartAtLogin(true);
            implementor.setStartAtLogin(true);
            ss.write(settings);
            final String newFile = FileUtils.readFileToString(temp, "UTF-8");
            assertTrue(newFile.contains("<true/>"));
        }
    }
    
    private File settingsFile() {
        return testFile("settings.json");
    }

    private File plist() {
        return testFile("plist");
    }

    private File testFile(final String name) {
        final File temp = new File(System.getProperty("java.io.tmpdir"), 
            String.valueOf(RandomUtils.nextInt()) + "." + name);
        temp.deleteOnExit();
        return temp;
    }
}
