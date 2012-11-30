package org.lantern;

import org.eclipse.swt.widgets.Display;

public class DisplayWrapper {

    private static final Display display = new Display();
    
    public static Display getDisplay() {
        return display;
    }
}
