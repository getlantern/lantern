package org.lantern.win;

import static org.junit.Assert.*;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;
import org.lantern.win.WindowsRegCommand;

/**
 * Test for the windows registry class that uses the reg command.
 */
public class WindowsRegCommandTest {
    
    @Test
    public void testReadAndWriteREG_SZ() throws Exception {
        if (!SystemUtils.IS_OS_WINDOWS) {
            return;
        }
        final String key = 
            "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
        final String valueName = "ProxyServer";
        final String str = WindowsRegCommand.read(key, valueName);
        
        final String testProxy = "127.0.0.1:7777";
        WindowsRegCommand.writeREG_SZ(key, valueName, testProxy);

        final String changed = WindowsRegCommand.read(key, valueName);
        assertEquals(changed, testProxy);
        
        WindowsRegCommand.writeREG_SZ(key, valueName, str);
    }

    @Test
    public void testReadAndWriteDword() throws Exception {
        if (!SystemUtils.IS_OS_WINDOWS) {
            return;
        }
        final String key = 
            "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
        final String valueName = "ProxyEnable";
        final String str = WindowsRegCommand.read(key, valueName);

        final boolean on = str.equals("1");
        final boolean off = str.equals("0");
        assertTrue(on || off);
        
        if (on) {
            WindowsRegCommand.writeREG_DWORD(key, valueName, 0);
        } else {
            WindowsRegCommand.writeREG_DWORD(key, valueName, 1);
        }
        
        final String changed = WindowsRegCommand.read(key, valueName);
        if (on) {
            assertEquals(changed, "0");
        } else {
            assertEquals(changed, "1");
        }
    }

}
