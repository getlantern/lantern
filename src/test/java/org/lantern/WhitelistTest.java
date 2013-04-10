package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;

import org.apache.commons.lang.math.RandomUtils;
import org.junit.Test;
import org.lantern.privacy.DefaultEncryptedFileService;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;


public class WhitelistTest {
    
    @Test
    public void testWhitelist() throws Exception {
        final LocalCipherProvider localCipherProvider = 
            new DefaultLocalCipherProvider();
        final DefaultEncryptedFileService fileService = 
            new DefaultEncryptedFileService(localCipherProvider);
        final File randFile = new File(Integer.toString(RandomUtils.nextInt()));

        final ModelIo modelIo = new ModelIo(randFile, fileService, null);
        randFile.delete();
        randFile.deleteOnExit();
        final Model settings = modelIo.get();
        final Whitelist whitelist = settings.getSettings().getWhitelist();
        
        assertTrue(whitelist.isWhitelisted("libertytimes.com.tw"));
        assertTrue(!whitelist.isWhitelisted("libertytimes.org.tw"));
        assertTrue(whitelist.isWhitelisted("on.cc"));
        assertTrue(whitelist.isWhitelisted("www.facebook.com:443"));
        assertTrue(whitelist.isWhitelisted("avaaz.org"));
        assertTrue(whitelist.isWhitelisted("getlantern.org"));
        assertTrue(whitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertTrue(whitelist.isWhitelisted("http://www.nytimes.com/"));
        assertTrue(whitelist.isWhitelisted("www.facebook.com:443"));
        assertTrue(whitelist.isWhitelisted("https://s-static.ak.facebook.com"));
        
        assertFalse(whitelist.isWhitelisted("notwhitelisted.org"));
        
        whitelist.addEntry("notwhitelisted.org");
        whitelist.removeEntry("nytimes.com");
        whitelist.removeEntry("avaaz.org");
        whitelist.removeEntry("getlantern.org");

        //final SettingsIo io = LanternHub.settingsIo();
        modelIo.write();
        final Model read2 = modelIo.get();
        final Whitelist readWhitelist = read2.getSettings().getWhitelist();
        
        assertFalse(readWhitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertFalse(readWhitelist.isWhitelisted("http://www.nytimes.com/"));
        assertFalse(readWhitelist.isWhitelisted("avaaz.org"));
        //assertTrue(readWhitelist.isWhitelisted("getlantern.org"));
        assertTrue(readWhitelist.isWhitelisted("notwhitelisted.org"));
        
        //assertTrue(readWhitelist.isWhitelisted("getlantern.org"));
        
        randFile.delete();
    }

    @Test
    public void testIPAddressInWhitelist() throws Exception {
        final ModelIo modelIo = TestUtils.getModelIo();
        //final File settingsFile = settingsFile();
        //final SettingsIo io = new SettingsIo(settingsFile, 
        //    new DefaultEncryptedFileService(new DefaultLocalCipherProvider()));
        final Model settings = modelIo.get();
        final Whitelist whitelist = settings.getSettings().getWhitelist();

        whitelist.addEntry("10.1.231.49");
        whitelist.addEntry("220.199.3.88");

        // basic - is it in the whitelist?
        assertTrue(whitelist.isWhitelisted("http://10.1.231.49"));
        assertTrue(whitelist.isWhitelisted("10.1.231.49"));
        assertTrue(whitelist.isWhitelisted("https://220.199.3.88"));
        assertTrue(whitelist.isWhitelisted("220.199.3.88"));

        // with ports
        assertTrue(whitelist.isWhitelisted("10.1.231.49:443"));
        assertTrue(whitelist.isWhitelisted("http://10.1.231.49:443"));
        assertTrue(whitelist.isWhitelisted("https://220.199.3.88:1999"));

        // with some request path
        assertTrue(whitelist.isWhitelisted("10.1.231.49:443/home/index.html"));
        assertTrue(whitelist.isWhitelisted("http://10.1.231.49/falling/water"));
        assertTrue(whitelist.isWhitelisted("https://220.199.3.88/new/page"));
        assertTrue(whitelist.isWhitelisted("220.199.3.88/get/lantern"));

        // these should not be in the list
        assertFalse(whitelist.isWhitelisted("10.1.231.4"));
        assertFalse(whitelist.isWhitelisted("100.1.231.49"));
        assertFalse(whitelist.isWhitelisted("259.199.3.88"));
    }

    private File settingsFile() {
        return testFile("settings.json");
    }

    private File testFile(final String name) {
        final File temp = new File(System.getProperty("java.io.tmpdir"), 
            String.valueOf(RandomUtils.nextInt()) + "." + name);
        temp.deleteOnExit();
        return temp;
    }
}
