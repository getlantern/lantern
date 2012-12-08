package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.state.ModelUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Guice;
import com.google.inject.Injector;


public class SettingsTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static DefaultXmppHandler xmppHandler;

    private static LanternSocketsUtil socketsUtil;

    private static LanternKeyStoreManager ksm;

    private static LanternXmppUtil lanternXmppUtil;

    private static Proxifier proxifier;

    private static EncryptedFileService encryptedFileService;

    private static ModelUtils modelUtils;
    /*
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        xmppHandler = injector.getInstance(DefaultXmppHandler.class);
        socketsUtil = injector.getInstance(LanternSocketsUtil.class);
        ksm = injector.getInstance(LanternKeyStoreManager.class);
        lanternXmppUtil = injector.getInstance(LanternXmppUtil.class);
        proxifier = injector.getInstance(Proxifier.class);
        encryptedFileService = injector.getInstance(EncryptedFileService.class);
        modelUtils = injector.getInstance(ModelUtils.class);
        
        xmppHandler.start();
    }
    
    @Test
    public void testSettingsUpdate() throws Exception {
        final File plist = plist();
        final File settingsFile = settingsFile();
        
        final SettingsIo io = new SettingsIo(settingsFile, encryptedFileService);
        final Settings settings = io.read();
        
        final Map<String, Object> update = new HashMap<String, Object>();
        update.put("system", "{'systemProxy' : false}}");
        
        //io.apply(update);
        
        
    }
    
    
    @Test
    public void testSettings() throws Exception {
        final File settingsFile = settingsFile();
        
        final SettingsIo io = new SettingsIo(settingsFile, encryptedFileService);
        final Settings settings = io.read();
        assertEquals(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT, 
            settings.getPort());
        
        final int port = 2830;
        settings.setPort(port);
        io.write(settings);
        
        final Settings read = io.read();
        assertEquals(port, read.getPort());
    }
    
    
    @Test
    public void testStartAtLogin() throws Exception {
        if (!LanternConstants.LAUNCHD_PLIST.isFile()) {
            log.info("No plist file - not installed or on different OS?");
            return;
        }
        final Settings settings = LanternHub.settings();
        final File temp1 = plist();
        final File temp2 = autostart();
        final File settingsFile = settingsFile();
        FileUtils.copyFile(new File("install/osx/org.lantern.plist"), temp1);
        FileUtils.copyFile(new File("install/linux/lantern-autostart.desktop"), temp2);
        final String cur1 = FileUtils.readFileToString(temp1, "UTF-8");
        final String cur2 = FileUtils.readFileToString(temp2, "UTF-8");
        assertTrue(cur1.contains("<true/>") || cur1.contains("<false/>"));
        assertTrue(cur2.contains("X-GNOME-Autostart-enabled=true") || 
                cur2.contains("X-GNOME-Autostart-enabled=false"));
        final SettingsIo ss = new SettingsIo(settingsFile, encryptedFileService);
        final DefaultSettingsChangeImplementor implementor = 
            new DefaultSettingsChangeImplementor(temp1, temp2, xmppHandler, proxifier, modelUtils);
        if (cur1.contains("<true/>")) {
            assertFalse(cur1.contains("<false/>"));
            //Configurator.setStartAtLogin(temp, false);
            settings.setStartAtLogin(false);
            implementor.setStartAtLoginOsx(false);
            ss.write(settings);
            final String newFile = FileUtils.readFileToString(temp1, "UTF-8");
            assertTrue(newFile.contains("<false/>"));
        } else if (cur1.contains("<false/>")) {
            assertFalse(cur1.contains("<true/>"));
            //Configurator.setStartAtLogin(temp, true);
            settings.setStartAtLogin(true);
            implementor.setStartAtLoginOsx(true);
            ss.write(settings);
            final String newFile = FileUtils.readFileToString(temp1, "UTF-8");
            assertTrue(newFile.contains("<true/>"));
        }
        
        if (cur2.contains("X-GNOME-Autostart-enabled=true")) {
            assertFalse(cur2.contains("<false/>"));
            //Configurator.setStartAtLogin(temp, false);
            settings.setStartAtLogin(false);
            implementor.setStartAtLoginLinux(false);
            ss.write(settings);
            final String newFile = FileUtils.readFileToString(temp2, "UTF-8");
            assertTrue(newFile.contains("X-GNOME-Autostart-enabled=false"));
        } else if (cur2.contains("X-GNOME-Autostart-enabled=false")) {
            assertFalse(cur2.contains("X-GNOME-Autostart-enabled=true"));
            //Configurator.setStartAtLogin(temp, true);
            settings.setStartAtLogin(true);
            implementor.setStartAtLoginLinux(true);
            ss.write(settings);
            final String newFile = FileUtils.readFileToString(temp2, "UTF-8");
            assertTrue(newFile.contains("X-GNOME-Autostart-enabled=true"));
        }
    }
    */
    
    private File autostart() {
        return testFile("lantern.desktop");
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
