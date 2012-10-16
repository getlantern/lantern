package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.apache.commons.io.IOUtils;

public class TestUtils {

    private static final File propsFile = 
        new File("src/test/resources/test.properties");
    
    private static final Properties props = new Properties();
    
    static {
        InputStream is = null;
        try {
            is = new FileInputStream(propsFile);
            props.load(is);
        } catch (final IOException e) {
            e.printStackTrace();
        } finally {
            IOUtils.closeQuietly(is);
        }
        
    }
    public static String loadTestEmail() {
        return props.getProperty("email");
    }
    
    public static String loadTestPassword() {
        return props.getProperty("pass");
    }
}
