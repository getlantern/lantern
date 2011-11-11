package org.lantern;

import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

public class BrowserTest {
    /**
     * @param args
     */
    public static void main(String[] args) {
        Display display = new Display();
        final Shell shell = new Shell(display);
        shell.setText("Lantern Installation");
        shell.setSize(700, 500);
        //shell.setImage
        //shell.setFullScreen(true);

        /*
        ToolBar toolbar = new ToolBar(shell, SWT.NONE);
        toolbar.setBounds(5, 5, 350, 30);
        ToolItem item1 = new ToolItem(toolbar, SWT.PUSH);
        item1.setText("Back");
        ToolItem item2 = new ToolItem(toolbar, SWT.PUSH);
        item2.setText("Forward");
        ToolItem item3 = new ToolItem(toolbar, SWT.PUSH);
        item3.setText("Refresh");
        ToolItem item4 = new ToolItem(toolbar, SWT.PUSH);
        item4.setText("Stop");
        ToolItem item5 = new ToolItem(toolbar, SWT.PUSH);
        item5.setText("Go");
        final Text text = new Text(shell, SWT.BORDER);
        text.setBounds(10, 35, 500, 25);
        */

        final Browser browser = new Browser(shell, SWT.NONE);
        //browser.setSize(700, 500);
        browser.setBounds(0, 0, 700, 500);
        //browser.setBounds(5, 75, 600, 400);

        /*
        Listener listener = new Listener() {
            public void handleEvent(Event event) {
                ToolItem item = (ToolItem) event.widget;
                String string = item.getText();
                if (string.equals("Back"))
                    browser.back();
                else if (string.equals("Forward"))
                    browser.forward();
                else if (string.equals("Refresh"))
                    browser.refresh();
                else if (string.equals("Stop"))
                    browser.stop();
                else if (string.equals("Go"))
                    browser.setUrl(text.getText());
            }
        };
        
        item1.addListener(SWT.Selection, listener);
        item2.addListener(SWT.Selection, listener);
        item3.addListener(SWT.Selection, listener);
        item4.addListener(SWT.Selection, listener);
        item5.addListener(SWT.Selection, listener);
        text.addListener(SWT.DefaultSelection, new Listener() {
            public void handleEvent(Event e) {
                browser.setUrl(text.getText());
            }
        });
        */
        shell.open();
        //browser.setUrl("http://www.roseindia.net");
        //browser.setUrl("file:///C:/cygwin/home/afisk/lantern/srv/install1.html");
        browser.setUrl("http://127.0.0.1:8383/install1.html");
        while (!shell.isDisposed()) {
            if (!display.readAndDispatch())
                display.sleep();
        }
        display.dispose();

    }
}