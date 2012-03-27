package org.lantern.win;

import com.sun.jna.Native;
import com.sun.jna.win32.StdCallLibrary;

/**
 * Adapted from:
 * 
 * http://stackoverflow.com/questions/5501787/invoke-wininet-functions-used-java-jna
 */
public interface Kernel32 extends StdCallLibrary {
    public Kernel32 INSTANCE = 
        (Kernel32) Native.loadLibrary("Kernel32", Kernel32.class);

    public int GetLastError();
}