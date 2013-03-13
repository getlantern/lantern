package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.JsonUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.Shutdownable;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.state.Notification.MessageType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Provider;
import com.google.inject.Singleton;

@Singleton
public class ModelIo implements Provider<Model>, Shutdownable {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File modelFile;

    private final Model model;

    private final EncryptedFileService encryptedFileService;

    /**
     * Creates a new instance with all the default operations.
     */
    @Inject
    public ModelIo(final EncryptedFileService encryptedFileService,
            Transfers transfers) {
        this(LanternClientConstants.DEFAULT_MODEL_FILE, encryptedFileService,
                transfers);
    }
    
    /**
     * Creates a new instance with custom settings typically used only in 
     * testing.
     * 
     * @param modelFile The file where settings are stored.
     */
    public ModelIo(final File modelFile,
        final EncryptedFileService encryptedFileService,
        Transfers transfers) {
        this.modelFile = modelFile;
        this.encryptedFileService = encryptedFileService;
        this.model = read();
        this.model.setTransfers(transfers);
        log.info("Loaded module");
    }

    @Override
    public Model get() {
        return this.model;
    }

    /**
     * Reads the state model from disk.
     * 
     * @return The {@link Model} instance as read from disk.
     */
    public Model read() {
        if (!modelFile.isFile()) {
            return blankModel();
        }
        final ObjectMapper mapper = new ObjectMapper();
        InputStream is = null;
        try {
            is = encryptedFileService.localDecryptInputStream(modelFile);
            final String json = IOUtils.toString(is);
            if (StringUtils.isBlank(json) || json.equalsIgnoreCase("null")) {
                log.info("Can't build settings from empty string");
                final Model mod = blankModel();
                mod.setModal(Modal.settingsLoadFailure);
                return mod;
            }
            final Model read = mapper.readValue(json, Model.class);
            //log.info("Built settings from disk: {}", read);
            if (!LanternUtils.persistCredentials()) {
                if (read.getModal() != Modal.welcome) {
                    read.setModal(Modal.authorize);
                }
            }
            
            // Make sure all peers are considered offline at startup.
            final Peers peers = read.getPeerCollector();
            peers.reset();
            return read;
        } catch (final IOException e) {
            log.error("Could not read model", e);
        } catch (final GeneralSecurityException e) {
            log.error("Security error?", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        final Model mod = blankModel();
        mod.setModal(Modal.settingsLoadFailure);
        return mod;
    }

    private Model blankModel() {
        log.info("Loading empty model!!");
        return new Model();
    }
    
    /**
     * Serializes the current model.
     */
    public void write() {
        write(this.model);
    }
    
    /**
     * Serializes the specified model -- useful for testing.
     */
    public void write(final Model toWrite) {
        if (LanternConstants.ON_APP_ENGINE) {
            log.debug("Not writing on app engine");
            return;
        }
        log.debug("Writing model!!");
        OutputStream os = null;
        try {
            final Settings set = toWrite.getSettings();
            final String refresh = set.getRefreshToken();
            final String access = set.getAccessToken();
            final boolean useOauth = set.isUseGoogleOAuth2();
            final boolean gtalk = toWrite.getConnectivity().isGtalkAuthorized();
            if (!LanternUtils.persistCredentials()) {
                
                set.setRefreshToken("");
                set.setAccessToken("");
                set.setUseGoogleOAuth2(false);
                toWrite.getConnectivity().setGtalkAuthorized(false);
                
            }
            final String json = JsonUtils.jsonify(toWrite,
                Model.Persistent.class);
            //log.info("Writing JSON: \n{}", json);
            os = encryptedFileService.localEncryptOutputStream(this.modelFile);
            os.write(json.getBytes("UTF-8"));
            
            if (!LanternUtils.persistCredentials()) {
                set.setRefreshToken(refresh);
                set.setAccessToken(access);
                set.setUseGoogleOAuth2(useOauth);
                toWrite.getConnectivity().setGtalkAuthorized(gtalk);
            }
        } catch (final IOException e) {
            log.error("Error encrypting stream", e);
        } catch (final GeneralSecurityException e) {
            log.error("Error encrypting stream", e);
        } finally {
            IOUtils.closeQuietly(os);
        }
    }

    @Override
    public void stop() {
        write();
    }

    public void reload() {
        Model newModel = read();
        if (newModel.getModal() == Modal.settingsLoadFailure) {
            model.addNotification("Failed to reload settings", MessageType.error);
            return;
        }
        model.loadFrom(newModel);
    }
}
