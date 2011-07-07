package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;

import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Tray;
import org.eclipse.swt.widgets.TrayItem;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all system tray interactions.
 */
public class SystemTrayImpl implements SystemTray {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Display display;
    private final Shell shell;

    /**
     * Creates a new system tray handler class.
     * 
     * @param display The SWT display. 
     */
    public SystemTrayImpl(final Display display) {
        this.display = display;
        this.shell = new Shell(display);
    }

    @Override
    public void createTray() {
        final Image image = newImage();
        
        final Tray tray = display.getSystemTray ();
        if (tray == null) {
            System.out.println ("The system tray is not available");
        } else {
            final TrayItem item = new TrayItem (tray, SWT.NONE);
            item.setToolTipText("Lantern");
            item.addListener (SWT.Show, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("show");
                }
            });
            item.addListener (SWT.Hide, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("hide");
                }
            });

            final Menu menu = new Menu (shell, SWT.POP_UP);
            final MenuItem quitItem = new MenuItem(menu, SWT.PUSH);
            quitItem.setText("Quit Lantern");
            quitItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Got exit call");
                    display.dispose();
                    System.exit(0);
                }
            });
            menu.setDefaultItem(quitItem);

            item.addListener (SWT.MenuDetect, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Setting menu visible");
                    menu.setVisible (true);
                }
            });
            item.setImage (image);
        }
    }

    private Image newImage() {
        final File iconFile;
        final File iconCandidate1 = new File("install/common/mg_16x16.png");
        if (iconCandidate1.isFile()) {
            iconFile = iconCandidate1;
        } else {
            iconFile = new File("mg_16x16.png");
        }
        if (!iconFile.isFile()) {
            log.error("Still no icon file at: " + iconFile);
        }
        InputStream is = null;
        try {
            is = new FileInputStream(iconFile);
            return new Image (display, is);
        } catch (FileNotFoundException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } 
        return new Image (display, 16, 16);
    }
}
