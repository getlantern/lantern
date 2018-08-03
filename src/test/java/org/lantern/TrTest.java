package org.lantern;

import static org.junit.Assert.*;

import java.util.Locale;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;

/**
 * Test for translated strings utility class.
 */
public class TrTest {

    private static Locale originalLocale;
    
    @BeforeClass
    public static void before() {
        originalLocale = Locale.getDefault();
    }
    
    @AfterClass
    public static void after() {
        Locale.setDefault(originalLocale);
    }
    
    @Test
    public void test() throws Exception {
        String cn = Tr.tr("CN");
        assertEquals("China", cn);
        Locale.setDefault(Locale.CHINA);
        Tr.reload();
        cn = Tr.tr("CN");
        assertEquals("中国", cn);
        
        // Set it to something we're unlikely to ever translate to test 
        // pass-through to english;
        Locale.setDefault(new Locale("en", "ZW"));
        Tr.reload();
        cn = Tr.tr("CN");
        assertEquals("China", cn);
    }

}
