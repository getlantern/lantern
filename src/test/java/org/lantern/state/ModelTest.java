package org.lantern.state;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.junit.Test;
import org.lantern.DefaultXmppHandler;
import org.lantern.LanternClientConstants;
import org.lantern.Proxifier;
import org.lantern.Roster;
import org.lantern.TestUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ModelTest {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Test
    public void testStartAtLogin() throws Exception {
        if (!LanternClientConstants.LAUNCHD_PLIST.isFile()) {
            log.info("No plist file - not installed or on different OS?");
            return;
        }
        final Model model = TestUtils.getModel();
        final Proxifier proxifier = TestUtils.getProxifier();
        final ModelUtils modelUtils = TestUtils.getModelUtils();
        final DefaultXmppHandler xmppHandler = TestUtils.getXmppHandler();
        final ModelIo modelIo = TestUtils.getModelIo();
        final Settings settings = model.getSettings();
        final Roster roster = TestUtils.getRoster();
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
            new DefaultModelService(temp1, temp2, model, proxifier, modelUtils, xmppHandler, roster);
        if (cur1.contains("<true/>")) {
            assertFalse(cur1.contains("<false/>"));
            //Configurator.setStartAtLogin(temp, false);
            settings.setRunAtSystemStart(false);
            implementor.setStartAtLoginOsx(false);
            modelIo.write();
            final String newFile = FileUtils.readFileToString(temp1, "UTF-8");
            assertTrue(newFile.contains("<false/>"));
        } else if (cur1.contains("<false/>")) {
            assertFalse(cur1.contains("<true/>"));
            //Configurator.setStartAtLogin(temp, true);
            settings.setRunAtSystemStart(true);
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
            settings.setRunAtSystemStart(false);
            implementor.setStartAtLoginLinux(false);
            modelIo.write();
            final String newFile = FileUtils.readFileToString(temp2, "UTF-8");
            assertTrue(newFile.contains("X-GNOME-Autostart-enabled=false"));
        } else if (cur2.contains("X-GNOME-Autostart-enabled=false")) {
            assertFalse(cur2.contains("X-GNOME-Autostart-enabled=true"));
            //Configurator.setStartAtLogin(temp, true);
            settings.setRunAtSystemStart(true);
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
