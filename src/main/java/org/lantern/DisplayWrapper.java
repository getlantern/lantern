package org.lantern;

import org.eclipse.swt.widgets.Display;

public class DisplayWrapper {

    // TODO: Make sure we always call dispose on the diplay.
    private static final Display display = new Display();
    
    public static Display getDisplay() {
        return display;
    }
}
