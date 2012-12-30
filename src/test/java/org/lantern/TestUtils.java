package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.apache.commons.io.IOUtils;
import org.lantern.http.JettyLauncher;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelService;
import org.lantern.state.ModelUtils;
import org.lantern.state.Settings;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class TestUtils {

    private static final File propsFile = 
        new File("src/test/resources/test.properties");
    
    private static final File privatePropsFile = 
        new File("private.properties");
    
    private static final Properties props = new Properties();
    
    private static final Properties privateProps = new Properties();

    private static DefaultXmppHandler xmppHandler;

    private static LanternSocketsUtil socketsUtil;

    private static LanternKeyStoreManager ksm;

    private static LanternXmppUtil lanternXmppUtil;

    private static Model model;
    
    private static LocalCipherProvider localCipherProvider;
    private static EncryptedFileService encryptedFileService;

    private static JettyLauncher jettyLauncher;
    
    private static MessageService messageService;

    private static Stats statsTracker;
    
    private static Roster roster;

    private static ModelService modelService;
    
    private static AnonymousPeerProxyManager anon;
    
    private static Proxifier proxifier;
    
    private static ModelIo modelIo;
    
    private static ModelUtils modelUtils;

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
        try {
            is = new FileInputStream(privatePropsFile);
            privateProps.load(is);
        } catch (final IOException e) {
            System.err.println("NO PRIVATE PROPS FILE AT "+
                privatePropsFile.getAbsolutePath());
            e.printStackTrace();
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    
    private static void load() {
        
        final Injector injector = Guice.createInjector(new LanternModule());
        
        xmppHandler = injector.getInstance(DefaultXmppHandler.class);
        socketsUtil = injector.getInstance(LanternSocketsUtil.class);
        ksm = injector.getInstance(LanternKeyStoreManager.class);
        lanternXmppUtil = injector.getInstance(LanternXmppUtil.class);
        localCipherProvider = injector.getInstance(LocalCipherProvider.class);
        encryptedFileService = injector.getInstance(EncryptedFileService.class);
        model = injector.getInstance(Model.class);
        jettyLauncher = injector.getInstance(JettyLauncher.class);
        messageService = injector.getInstance(MessageService.class);
        statsTracker = injector.getInstance(Stats.class);
        roster = injector.getInstance(Roster.class);
        modelService = injector.getInstance(ModelService.class);
        anon = injector.getInstance(AnonymousPeerProxyManager.class);
        proxifier = injector.getInstance(Proxifier.class);
        modelUtils = injector.getInstance(ModelUtils.class);
        modelIo = injector.getInstance(ModelIo.class);
        
        final Settings set = model.getSettings();
        set.setAccessToken(getAccessToken());
        set.setRefreshToken(getRefreshToken());
        set.setUseGoogleOAuth2(true);
        xmppHandler.start();
    }
    
    public static String loadTestEmail() {
        return props.getProperty("email");
    }
    
    public static String loadTestPassword() {
        return props.getProperty("pass");
    }

    public static String getRefreshToken() {
        return privateProps.getProperty("refresh_token");
    }

    public static String getAccessToken() {
        return privateProps.getProperty("access_token");
    }
    
    public static String getUserName() {
        return privateProps.getProperty("username");
    }

    public static JettyLauncher getJettyLauncher() {
        if (jettyLauncher == null) {
            load();
        }
        return jettyLauncher;
    }
    
    public static DefaultXmppHandler getXmppHandler() {
        if (xmppHandler == null) {
            load();
        }
        return xmppHandler;
    }

    public static LanternSocketsUtil getSocketsUtil() {
        if (socketsUtil == null) {
            load();
        }
        return socketsUtil;
    }

    public static LanternKeyStoreManager getKsm() {
        if (ksm == null) {
            load();
        }
        return ksm;
    }

    public static LanternXmppUtil getLanternXmppUtil() {
        if (lanternXmppUtil == null) {
            load();
        }
        return lanternXmppUtil;
    }

    public static Model getModel() {
        if (model == null) {
            load();
        }
        return model;
    }
    
    public static LocalCipherProvider getLocalCipherProvider() {
        if (localCipherProvider == null) {
            load();
        }
        return localCipherProvider;
    }

    public static EncryptedFileService getEncryptedFileService() {
        if (encryptedFileService == null) {
            load();
        }
        return encryptedFileService;
    }

    public static MessageService getMessageService() {
        if (messageService == null) {
            load();
        }
        return messageService;
    }
    

    public static Stats getStatsTracker() {
        if (statsTracker == null) {
            load();
        }
        return statsTracker;
    }
    
    public static Roster getRoster() {
        if (roster == null) {
            load();
        }
        return roster;
    }

    public static ModelService getModelService() {
        if (modelService == null) {
            load();
        }
        return modelService;
    }

    public static AnonymousPeerProxyManager getAnon() {
        return anon;
    }
    
    
    public static Proxifier getProxifier() {
        return proxifier;
    }

    public static ModelIo getModelIo() {
        return modelIo;
    }

    public static ModelUtils getModelUtils() {
        return modelUtils;
    }
}
