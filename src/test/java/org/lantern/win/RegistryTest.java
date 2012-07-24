package org.lantern.win;

import static org.junit.Assert.assertEquals;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.jna.platform.win32.Advapi32Util;
import com.sun.jna.platform.win32.WinReg;

/**
 * Test the registry code.
 */
public class RegistryTest {

    private static final Logger LOG = LoggerFactory.getLogger(RegistryTest.class);
    
    /**
     * Sending registry values with quotes to the java external process system
     * requires extra escaping of quotes, so just make sure we handle it and
     * get the same results as call to the advapi stuff.
     * 
     * @throws Exception If any unexpected error occurs.
     */
    @Test
    public void testRegistryValuesWithQuotes() throws Exception {
        if (!SystemUtils.IS_OS_WINDOWS) {
            return;
        }
        final String key = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
        final String fewerQuotes = 
            "\""+new File("Lantern.exe").getCanonicalPath()+"\"" + " --launchd";
        final String name = "Lantern";
        
        writeWithAdvApi(key, name, fewerQuotes);
        String advResult = Registry.read(key, name);
        writeWithCommandReg(key, name, fewerQuotes);
        String regResult = Registry.read(key, name);
        assertEquals(advResult, regResult);
    }

    private boolean writeWithAdvApi(final String key, final String name, 
        final String value) {
        Advapi32Util.registrySetStringValue(WinReg.HKEY_CURRENT_USER, key, 
            name, value);
        return true;
    }
    
    private static boolean writeWithCommandReg(final String key, 
        final String name, final String value) {
        final int exit = 
            WindowsRegCommand.writeREG_SZ("HKCU\\"+key, name, value.toString());
        final boolean succeeded = exit == 0;
        if (!succeeded) {
            LOG.warn("Could not write to reg with REG command either: "+key);
        } else {
            LOG.info("Successfully wrote ot registry with REG command");
        }
        return succeeded;
    }
}
