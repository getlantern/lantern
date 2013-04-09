package org.lantern.state;

import java.io.File;

import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.state.Notification.MessageType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class ModelIo extends Storage<Model> {

    private final Logger log = LoggerFactory.getLogger(getClass());

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
     * @param modelFile
     *            The file where settings are stored.
     */
    public ModelIo(final File modelFile,
            final EncryptedFileService encryptedFileService, Transfers transfers) {
        super(encryptedFileService, modelFile, Model.class);
        obj = read();
        obj.setTransfers(transfers);
        log.info("Loaded module");
    }

    /**
     * Reads the state model from disk.
     *
     * @return The {@link Model} instance as read from disk.
     */
    @Override
    public Model read() {
        try {
            Model read = super.read();
            if (!LanternUtils.persistCredentials()) {
                if (read.getModal() != Modal.welcome) {
                    read.setModal(Modal.authorize);
                }
            }

            // Make sure all peers are considered offline at startup.
            final Peers peers = read.getPeerCollector();
            peers.reset();
            if (read.getModal() == Modal.settingsLoadFailure) {
                read.setModal(Modal.none);
            }
            return read;
        } catch (ModelReadFailedException e) {
            log.info("Failed to read model", e);
            Model blank = blank();
            blank.setModal(Modal.settingsLoadFailure);
            return blank;
        } catch (Exception e) {
            log.info("Failed to read model for some other reason", e);
            Model blank = blank();
            return blank;
        }
    }

    @Override
    protected Model blank() {
        log.info("Loading empty model!!");
        Model mod = new Model();
        return mod;
    }

    /**
     * Serializes the specified model -- useful for testing.
     */
    @Override
    public void write(final Model toWrite) {
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
        super.write(toWrite);
        if (!LanternUtils.persistCredentials()) {
            set.setRefreshToken(refresh);
            set.setAccessToken(access);
            set.setUseGoogleOAuth2(useOauth);
            toWrite.getConnectivity().setGtalkAuthorized(gtalk);
        }
    }

    public void reload() {
        Model newModel = read();
        if (newModel.getModal() == Modal.welcome) {
            //if modal is welcome, then we are dealing with fresh settings
            obj.addNotification("Failed to reload settings", MessageType.error);
            return;
        }
        obj.loadFrom(newModel);
    }
}
