package org.lantern.state;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.DefaultXmppHandler;
import org.lantern.LanternConstants;
import org.lantern.LanternModule;
import org.lantern.Proxifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class ModelTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static DefaultXmppHandler xmppHandler;

    private static Proxifier proxifier;

    private static ModelUtils modelUtils;

    private static Model model;

    private static ModelIo modelIo;

    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        xmppHandler = injector.getInstance(DefaultXmppHandler.class);
        proxifier = injector.getInstance(Proxifier.class);
        modelUtils = injector.getInstance(ModelUtils.class);
        modelIo = injector.getInstance(ModelIo.class);
        //implementor = injector.getInstance(DefaultModelChangeImplementor.class);
        
        model = injector.getInstance(Model.class);
    }
    
    @Test
    public void testStartAtLogin() throws Exception {
        if (!LanternConstants.LAUNCHD_PLIST.isFile()) {
            log.info("No plist file - not installed or on different OS?");
            return;
        }
        final Settings settings = model.getSettings();
        final File temp1 = plist();
        final File temp2 = autostart();
        //final File settingsFile = settingsFile();
        FileUtils.copyFile(new File("install/osx/org.lantern.plist"), temp1);
        FileUtils.copyFile(new File("install/linux/lantern-autostart.desktop"), temp2);
        final String cur1 = FileUtils.readFileToString(temp1, "UTF-8");
        final String cur2 = FileUtils.readFileToString(temp2, "UTF-8");
        assertTrue(cur1.contains("<true/>") || cur1.contains("<false/>"));
        assertTrue(cur2.contains("X-GNOME-Autostart-enabled=true") || 
                cur2.contains("X-GNOME-Autostart-enabled=false"));
        //final SettingsIo ss = new SettingsIo(settingsFile, encryptedFileService);
        final DefaultModelService implementor = 
            new DefaultModelService(temp1, temp2, model, proxifier, modelUtils, xmppHandler);
        if (cur1.contains("<true/>")) {
            assertFalse(cur1.contains("<false/>"));
            //Configurator.setStartAtLogin(temp, false);
            settings.setRunOnSystemStartup(false);
            implementor.setStartAtLoginOsx(false);
            modelIo.write();
            final String newFile = FileUtils.readFileToString(temp1, "UTF-8");
            assertTrue(newFile.contains("<false/>"));
        } else if (cur1.contains("<false/>")) {
            assertFalse(cur1.contains("<true/>"));
            //Configurator.setStartAtLogin(temp, true);
            settings.setRunOnSystemStartup(true);
            implementor.setStartAtLoginOsx(true);
            modelIo.write();
            final String newFile = FileUtils.readFileToString(temp1, "UTF-8");
            assertTrue(newFile.contains("<true/>"));
        } else {
            fail("Model should have some start at login state");
        }
        
        if (cur2.contains("X-GNOME-Autostart-enabled=true")) {
            assertFalse(cur2.contains("<false/>"));
            //Configurator.setStartAtLogin(temp, false);
            settings.setRunOnSystemStartup(false);
            implementor.setStartAtLoginLinux(false);
            modelIo.write();
            final String newFile = FileUtils.readFileToString(temp2, "UTF-8");
            assertTrue(newFile.contains("X-GNOME-Autostart-enabled=false"));
        } else if (cur2.contains("X-GNOME-Autostart-enabled=false")) {
            assertFalse(cur2.contains("X-GNOME-Autostart-enabled=true"));
            //Configurator.setStartAtLogin(temp, true);
            settings.setRunOnSystemStartup(true);
            implementor.setStartAtLoginLinux(true);
            modelIo.write();
            final String newFile = FileUtils.readFileToString(temp2, "UTF-8");
            assertTrue(newFile.contains("X-GNOME-Autostart-enabled=true"));
        } else {
            fail("Gnome autostart should be in some state");
        }
    }

    
    private File autostart() {
        return testFile("lantern.desktop");
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
