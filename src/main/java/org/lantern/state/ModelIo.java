package org.lantern.state;

import java.io.File;

import org.apache.commons.cli.CommandLine;
import org.lantern.Country;
import org.lantern.CountryService;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.Launcher;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.state.Notification.MessageType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class ModelIo extends Storage<Model> {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final CountryService countryService;
    private final CommandLine commandLine;

    /**
     * Creates a new instance with all the default operations.
     */
    @Inject
    public ModelIo(final EncryptedFileService encryptedFileService,
            final Transfers transfers, final CountryService countryService,
            final CommandLine commandLine) {
        this(LanternClientConstants.DEFAULT_MODEL_FILE, encryptedFileService,
                transfers, countryService, commandLine);
    }

    /**
     * Creates a new instance with custom settings typically used only in
     * testing.
     *
     * @param modelFile
     *            The file where settings are stored.
     * @param commandLine The command line arguments. 
     */
    public ModelIo(final File modelFile,
            final EncryptedFileService encryptedFileService, Transfers transfers,
            final CountryService countryService, final CommandLine commandLine) {
        super(encryptedFileService, modelFile, Model.class);
        this.countryService = countryService;
        this.commandLine = commandLine;
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
            final Model read = super.read();
            read.setCountryService(countryService);
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
            boolean isCensored = false;
            String countryCode = read.getLocation().getCountry();
            if (countryCode != null) {
                Country country = countryService.getCountryByCode(countryCode);
                if (country != null) {
                    isCensored = country.isCensors();
                }
            }
            if (!isCensored && read.getModal() == Modal.giveModeForbidden) {
                read.setModal(Modal.none);
            }
            setServerPort(this.commandLine, read);
            return read;
        } catch (final ModelReadFailedException e) {
            log.error("Failed to read model", e);
            Model blank = blank();
            blank.setModal(Modal.settingsLoadFailure);
            return blank;
        } catch (final Exception e) {
            log.error("Failed to read model for some other reason", e);
            Model blank = blank();
            return blank;
        }
    }
    
    /**
     * We need to make sure to set the server port before anything is 
     * injected -- otherwise we run the risk of running on a completely 
     * different port than what is passed on the command line!
     * 
     * @param cmd The command line.
     * @param read The model
     */
    private void setServerPort(final CommandLine cmd, final Model read) {
        if (cmd == null) {
            // Can be true for testing.
            log.error("No command line?");
        }
        final Settings set = read.getSettings();
        if (cmd.hasOption(Launcher.OPTION_SERVER_PORT)) {
            final String serverPortStr =
                cmd.getOptionValue(Launcher.OPTION_SERVER_PORT);
            log.debug("Using command-line proxy port: "+serverPortStr);
            final int serverPort = Integer.parseInt(serverPortStr);
            set.setServerPort(serverPort);
        } else {
            final int existing = set.getServerPort();
            if (existing < 1024) {
                log.debug("Using random give mode proxy port...");
                set.setServerPort(LanternUtils.randomPort());
            }
        }
        log.info("Running give mode proxy on port: {}", set.getServerPort());
    }

    @Override
    protected Model blank() {
        log.info("Loading empty model!!");
        Model mod = new Model(countryService);
        return mod;
    }

    /**
     * Serializes the specified model -- useful for testing.
     */
    @Override
    public synchronized void write(final Model toWrite) {
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
        newModel.setCountryService(countryService);
        if (newModel.getModal() == Modal.welcome) {
            //if modal is welcome, then we are dealing with fresh settings
            obj.addNotification("Failed to reload settings", MessageType.error);
            return;
        }
        obj.loadFrom(newModel);
    }
}
