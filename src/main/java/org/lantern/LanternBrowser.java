package org.lantern;

import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

public class LanternBrowser {

    private Shell shell;
    private Display display;
    private Browser browser;

    public LanternBrowser() {
        this.display = new Display();
        this.shell = new Shell(display);
        shell.setText("Lantern Installation");
        shell.setSize(700, 500);
        shell.setFullScreen(true);

        this.browser = new Browser(shell, SWT.NONE);
        //browser.setSize(700, 500);
        browser.setBounds(0, 0, 700, 500);
        //browser.setBounds(5, 75, 600, 400);

        shell.open();
    }
    
    public void install() {
        //browser.setUrl("http://127.0.0.1:8383/install1.html");
        browser.setUrl(LanternConstants.BASE_URL+"/install1?key="+
            LanternUtils.keyString());
        while (!shell.isDisposed()) {
            if (!display.readAndDispatch())
                display.sleep();
        }
        display.dispose();
    }
}
