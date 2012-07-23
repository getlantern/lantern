package org.lantern.win;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;

public class RegistryTest {

    @Test
    public void testRegistryValuesWithQuotes() throws Exception {
        if (!SystemUtils.IS_OS_WINDOWS) {
            return;
        }
        final String key = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
        final String fewerQuotes = 
            "\""+new File("Lantern.exe").getCanonicalPath()+"\"" + " --launchd";
        final String lotsOfQuotes = 
            "\"\\\""+new File("Lantern.exe").getCanonicalPath()+"\\\"\"" + " --launchd";
        
        final String name = "Lantern";
        Registry.write(key, name, fewerQuotes);
        final String result = Registry.read(key, name);
        
        System.out.println("RESULT 1: "+result);
    }
}
