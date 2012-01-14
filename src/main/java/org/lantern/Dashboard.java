package org.lantern;

import java.io.File;

import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.widgets.Monitor;
import org.eclipse.swt.widgets.Shell;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Browser dashboard for controlling lantern.
 */
public class Dashboard {
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    /**
     * Opens the browser.
     */
    public void openBrowser() {
        LanternHub.display().syncExec(new Runnable() {
            @Override
            public void run() {
                buildBrowser();
            }
        });
    }
    
    protected void buildBrowser() {
        log.info("Creating shell...");
        final Shell shell = new Shell(LanternHub.display());
        final Image small = newImage("16on.png");
        final Image medium = newImage("32on.png");
        final Image large = newImage("64on.png");
        final Image[] icons = new Image[]{small, medium, large};
        shell.setImages(icons);
        // this.shell = createShell(this.display);
        shell.setText("Lantern Dashboard");
        //this.shell.setSize(720, 540);
        // shell.setFullScreen(true);

        log.debug("Centering on screen...");
        final Monitor primary = LanternHub.display().getPrimaryMonitor();
        final Rectangle bounds = primary.getBounds();
        final Rectangle rect = shell.getBounds();

        final int x = bounds.x + (bounds.width - rect.width) / 2;
        final int y = bounds.y + (bounds.height - rect.height) / 2;

        shell.setLocation(x, y);
        
        log.info("Creating new browser...");
        final Browser browser = new Browser(shell, SWT.NONE);
        browser.setSize(800, 600);
        //browser.setBounds(0, 0, 800, 600);
        browser.setUrl("http://localhost:"+
            LanternHub.settings().getApiPort()+"/dashboard.html");
        shell.open();
        shell.forceActive();
        while (!shell.isDisposed()) {
            if (!LanternHub.display().readAndDispatch())
                LanternHub.display().sleep();
        }
    }

    private Image newImage(final String path) {
        final String toUse;
        final File path1 = new File(path);
        if (path1.isFile()) {
            toUse = path1.getAbsolutePath();
        } else {
            final File path2 = new File("install/common", path);
            toUse = path2.getAbsolutePath();
        }
        return new Image(LanternHub.display(), toUse);
    }
}
