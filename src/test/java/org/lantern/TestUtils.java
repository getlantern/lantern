package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.apache.commons.io.IOUtils;
import org.lantern.state.Model;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class TestUtils {

    private static final File propsFile = 
        new File("src/test/resources/test.properties");
    
    private static final Properties props = new Properties();
    

    private static final DefaultXmppHandler xmppHandler;

    private static final LanternSocketsUtil socketsUtil;

    private static final LanternKeyStoreManager ksm;

    private static final LanternXmppUtil lanternXmppUtil;

    private static final Model model;
    
    
    static {
        InputStream is = null;
        try {
            is = new FileInputStream(propsFile);
            props.load(is);
        } catch (final IOException e) {
            System.err.println("PLEASE ENTER email AND pass FIELDS IN "+
                propsFile.getAbsolutePath());
            e.printStackTrace();
        } finally {
            IOUtils.closeQuietly(is);
        }
        
        final Injector injector = Guice.createInjector(new LanternModule());
        
        xmppHandler = injector.getInstance(DefaultXmppHandler.class);
        socketsUtil = injector.getInstance(LanternSocketsUtil.class);
        ksm = injector.getInstance(LanternKeyStoreManager.class);
        lanternXmppUtil = injector.getInstance(LanternXmppUtil.class);
        model = injector.getInstance(Model.class);
        
        xmppHandler.start();
        
    }
    public static DefaultXmppHandler getXmppHandler() {
        return xmppHandler;
    }

    public static LanternSocketsUtil getSocketsUtil() {
        return socketsUtil;
    }

    public static LanternKeyStoreManager getKsm() {
        return ksm;
    }

    public static LanternXmppUtil getLanternXmppUtil() {
        return lanternXmppUtil;
    }

    public static Model getModel() {
        return model;
    }

    public static File getPropsfile() {
        return propsFile;
    }

    public static Properties getProps() {
        return props;
    }

    public static String loadTestEmail() {
        return props.getProperty("email");
    }
    
    public static String loadTestPassword() {
        return props.getProperty("pass");
    }
}
