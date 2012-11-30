package org.lantern;

import org.eclipse.swt.widgets.Display;

public class DisplayWrapper {

    // TODO: Make sure we always call dispose on the diplay.
    private static Display display;
    
    public synchronized static Display getDisplay() {
        if (display == null) {
            display = new Display();
        }
        return display;
    }
}
