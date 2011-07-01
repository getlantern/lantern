package org.lantern;

import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Monitor;
import org.eclipse.swt.widgets.Shell;

public class LanternBrowser {

    private Shell shell;
    //private Display display;
    private Browser browser;
    
    private Display display;

    public LanternBrowser() {
        Display.setAppName("Lantern");
        this.display = new Display();
        //
        this.shell = new Shell(display);
        //this.shell = createShell(this.display);
        this.shell.setText("Lantern Installation");
        this.shell.setSize(720, 540);
        //shell.setFullScreen(true);
        
        final Monitor primary = this.display.getPrimaryMonitor();
        final Rectangle bounds = primary.getBounds();
        final Rectangle rect = shell.getBounds();
        
        final int x = bounds.x + (bounds.width - rect.width) / 2;
        final int y = bounds.y + (bounds.height - rect.height) / 2;
        
        shell.setLocation(x, y);

        this.browser = new Browser(shell, SWT.NONE);
        //browser.setSize(700, 500);
        browser.setBounds(0, 0, 700, 560);
        //browser.setBounds(5, 75, 600, 400);

        shell.open();
    }
    
    public void install() {
        //browser.setUrl("http://127.0.0.1:8383/install1.html");
        browser.setUrl(LanternConstants.BASE_URL+"/install1?key="+
            LanternUtils.keyString());
        while (!shell.isDisposed()) {
            if (!this.display.readAndDispatch())
                this.display.sleep();
        }
        this.display.dispose();
    }
    
    public void close() {
        display.syncExec(new Runnable() {
            public void run() {
                shell.dispose();
            }
        });
    }
}
