package org.lantern;

import java.awt.Image;
import java.awt.MenuItem;
import java.awt.PopupMenu;
import java.awt.Toolkit;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.net.MalformedURLException;

import javax.swing.UIManager;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all system tray interactions.
 */
public class SystemTrayImpl implements SystemTray {

    private final Logger log = LoggerFactory.getLogger(getClass());

    /**
     * Creates a new system tray handler class.
     */
    public SystemTrayImpl() {
        // createTray();
    }

    public void createTray() {
        // This is only enabled on Windows for now because it creates a screen
        // menu bar on OSX.
        if (SystemUtils.isJavaVersionAtLeast(1.6f)
                && NativeUtils.supportsTray()) {
            if (SystemUtils.IS_OS_WINDOWS) {
                try {
                    UIManager.setLookAndFeel(UIManager
                            .getSystemLookAndFeelClassName());
                } catch (final Exception e2) {
                    log.error("Could not set look and feel", e2);
                }
            }
            final File iconFile;
            final File iconCandidate1 = new File(
                    "src/main/resources/mg_16x16.png");
            if (iconCandidate1.isFile()) {
                iconFile = iconCandidate1;
            } else {
                iconFile = new File("mg_16x16.png");
            }
            if (!iconFile.isFile()) {
                log.error("Still no icon file at: " + iconFile);
            }
            final Image image;
            try {
                image = Toolkit.getDefaultToolkit().getImage(
                        iconFile.toURI().toURL());
            } catch (final MalformedURLException e) {
                log.error("Could not load icon", e);
                return;
            }
            final PopupMenu popup = new PopupMenu();

            final MenuItem quitItem = new MenuItem("Quit Lantern");
            quitItem.addActionListener(new ActionListener() {
                public void actionPerformed(ActionEvent e) {
                    System.out.println("Got exit call");
                    System.exit(0);
                }

            });
            popup.add(quitItem);
            System.out.println("Adding system tray...");
            NativeUtils.addTray(image, "Lantern", popup);
        } else {
            log.debug("System tray not supported..");
        }
    }

}
