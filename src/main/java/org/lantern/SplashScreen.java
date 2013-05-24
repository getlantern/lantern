package org.lantern;


import java.awt.DisplayMode;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.io.File;

import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.FormAttachment;
import org.eclipse.swt.layout.FormData;
import org.eclipse.swt.layout.FormLayout;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.ProgressBar;
import org.eclipse.swt.widgets.Shell;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

@Singleton
public class SplashScreen implements Shutdownable {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private Image image;
    private Shell splash;
    private ProgressBar bar;
    private Display display;

    int progress = 0;
    private Label label;

    public void init(final Display display) {
        this.display = display;
        final File installed = new File("lantern-ui/img/splash.png");
        final String splashImage;
        if (installed.isFile()) {
            splashImage = installed.getAbsolutePath();
        } else {
            splashImage = "lantern-ui/app/img/splash.png";
        }

        image = new Image(display, splashImage);
        splash = new Shell(SWT.NO_TRIM);
        bar = new ProgressBar(splash, SWT.NONE);

        //The number of modules loaded in Launcher.launch()
        bar.setMaximum(24);
        label = new Label(splash, SWT.NONE);
        label.setImage(image);
        FormLayout layout = new FormLayout();
        splash.setLayout(layout);
        FormData labelData = new FormData ();
        labelData.right = new FormAttachment (100, 0);
        labelData.bottom = new FormAttachment (100, 0);
        label.setLayoutData(labelData);
        FormData progressData = new FormData ();
        progressData.left = new FormAttachment (0, 5);
        progressData.right = new FormAttachment (100, -5);
        progressData.bottom = new FormAttachment (100, -5);
        bar.setLayoutData(progressData);
        splash.pack();
        Rectangle splashRect = splash.getBounds();


        GraphicsDevice defaultDevice = GraphicsEnvironment
            .getLocalGraphicsEnvironment()
            .getDefaultScreenDevice();

        DisplayMode displayMode = defaultDevice.getDisplayMode();

        int x = (displayMode.getWidth() - splashRect.width) / 2;
        int y = (displayMode.getHeight() - splashRect.height) / 2;
        splash.setLocation(x, y);
        splash.open();
        splash.forceActive();
        display.update();
        while(display.readAndDispatch())
                //do nothing
                ;
    }

    public void advanceBar() {
        if (display == null || Thread.currentThread() != display.getThread()) {
            log.warn("Calling advanceBar outside of SWT thread is forbidden");
            return;
        }
        if (bar != null) {
            bar.setSelection(++progress);
            while(display.readAndDispatch())
                //do nothing
                ;
        }
    }

    public void stop() {
        close();
    }

    public void close() {
        if (splash != null) {
            display.asyncExec(new Runnable() {
                @Override
                public void run() {
                    //double-check for completion inside synchronized block
                    synchronized(SplashScreen.this) {
                        if (splash != null) {
                            splash.close();
                            image.dispose();

                            splash = null;
                            image = null;
                        }
                    }
                }
            });
        }
    }
}
