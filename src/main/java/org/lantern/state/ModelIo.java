package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;
import java.util.Arrays;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.EncryptedFileService;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.Shutdownable;
import org.lantern.privacy.InvalidKeyException;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.privacy.UserInputRequiredException;
import org.lantern.ui.SwtMessageService;
import org.lantern.ui.SwtPasswordDialog;
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

    private final LocalCipherProvider localCipherProvider;
    
    /**
     * Creates a new instance with all the default operations.
     */
    @Inject
    public ModelIo(final EncryptedFileService encryptedFileService,
        final LocalCipherProvider localCipherProvider) {
        this(LanternConstants.DEFAULT_MODEL_FILE, encryptedFileService, 
                localCipherProvider);
    }
    
    /**
     * Creates a new instance with custom settings typically used only in 
     * testing.
     * 
     * @param modelFile The file where settings are stored.
     */
    public ModelIo(final File modelFile, 
        final EncryptedFileService encryptedFileService,
        final LocalCipherProvider localCipherProvider) {
        this.modelFile = modelFile;
        this.encryptedFileService = encryptedFileService;
        this.localCipherProvider = localCipherProvider;
        this.model = read();
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
            //return blankModel();
            // This means the user has either reset their system or has never
            // run before. If they're on a system that locks the state file
            // with a manual password, we need to prompt the user for that
            // here.
            if (!this.localCipherProvider.isInitialized()) {
                /*
                final String password = establishPassword();
                try {
                    localCipherProvider.feedUserInput(password.toCharArray(), true);
                } catch (final GeneralSecurityException e) {
                    log.error("Unexpected error setting initial password: {}",e);
                } catch (final IOException e) {
                    log.error("Unexpected error setting initial password: {}",e);
                }
                */
            }
            return blankModel();
        }
        final ObjectMapper mapper = new ObjectMapper();
        InputStream decrypted = decryptedModel();
        //InputStream is = null;
        try {
            //is = encryptedFileService.localDecryptInputStream(modelFile);
            final String json = IOUtils.toString(decrypted);
            //log.info("Building model from json string...\n{}", json);
            if (StringUtils.isBlank(json) || json.equalsIgnoreCase("null")) {
                log.info("Can't build settings from empty string");
                return blankModel();
            }
            final Model read = mapper.readValue(json, Model.class);
            //log.info("Built settings from disk: {}", read);
            return read;
        } catch (final IOException e) {
            log.error("Could not read model", e);
        } finally {
            IOUtils.closeQuietly(decrypted);
        }
        final Model mod = blankModel();
        mod.setModal(Modal.settingsLoadFailure);
        return mod;
    }
    

    private InputStream decryptedModel() {
        try {
            return encryptedFileService.localDecryptInputStream(modelFile);
        } catch (final UserInputRequiredException e) {
            log.info("Settings require password to be unlocked.");
            try {
                keepAskingForPassword();
            } catch (final UserInputRequiredException e1) {
                // This means the user has canceled the dialog. Ask one more
                // time and then exit.
                final SwtMessageService ms = new SwtMessageService();
                if (ms.askQuestion("Quit Lantern", "Lantern cannot run without a password. Quit Lantern now?")) {
                    System.exit(0);
                } else {
                    // Ask one more time.
                    try {
                        keepAskingForPassword();
                    } catch (final UserInputRequiredException uire) {
                        // OK, the user canceled a second time. Just exit.
                        System.exit(0);
                    }
                }
            }
            try {
                return encryptedFileService.localDecryptInputStream(modelFile);
            } catch (final IOException e1) {
                log.warn("Still could not read file", e1);
            } catch (final GeneralSecurityException e1) {
                log.warn("Still could not read file", e1);
            }
        } catch (final IOException e) {
            log.warn("Still could not read file", e);
        } catch (final GeneralSecurityException e) {
            log.warn("Still could not read file", e);
        } 
        // If we get here, that means we definitely have not been able to get
        // a legitimate password from the user.
        final SwtMessageService ms = new SwtMessageService();
        ms.showMessage("Exiting Lantern", "We're sorry, but we could not start Lantern without a valid password. Exiting");
        System.exit(0);
        throw new Error("Could not read model state file!!");
    }

    private void keepAskingForPassword() throws UserInputRequiredException {
        String errorMessage = "";
        while (true) {
            final SwtPasswordDialog spd = new SwtPasswordDialog(errorMessage);
            final String pwd = spd.askForPassword();
            try {
                this.localCipherProvider.feedUserInput(pwd.toCharArray(), false);
            } catch (final UserInputRequiredException e) {
                throw e;
            } catch (final IOException e) {
                errorMessage = "Invalid password. Please try again.";
            } catch (final GeneralSecurityException e) {
                errorMessage = "Invalid password. Please try again.";
            }
        }
    }

    private boolean askToUnlockSettingsCLI() {
        if (!localCipherProvider.requiresAdditionalUserInput()) {
            log.info("Local cipher does not require a password.");
            return true;
        }
        while(true) {
            char [] pw = null; 
            try {
                pw = readSettingsPasswordCLI();
                return unlockSettingsWithPassword(pw);
            }
            catch (final InvalidKeyException e) {
                System.out.println("Password was incorrect, try again."); // XXX i18n
            }
            catch (final GeneralSecurityException e) {
                log.error("Error unlocking settings: {}", e);
            }
            catch (final IOException e) {
                log.error("Erorr unlocking settings: {}", e);
            }
            finally {
                LanternUtils.zeroFill(pw);
            }
        }
    }
    
    private char [] readSettingsPasswordCLI() throws IOException {
        if (localCipherProvider.isInitialized() == false) {
            while (true) {
                // XXX i18n
                System.out.print("Please enter a password to protect your local data:");
                System.out.flush();
                final char [] pw1 = LanternUtils.readPasswordCLI();
                if (pw1.length == 0) {
                    System.out.println("password cannot be blank, please try again.");
                    System.out.flush();
                    continue;
                }
                System.out.print("Please enter password again:");
                System.out.flush();
                final char [] pw2 = LanternUtils.readPasswordCLI();
                if (Arrays.equals(pw1, pw2)) {
                    // zero out pw2
                    LanternUtils.zeroFill(pw2);
                    return pw1;
                }
                else {
                    LanternUtils.zeroFill(pw1);
                    LanternUtils.zeroFill(pw2);
                    System.out.println("passwords did not match, please try again.");
                    System.out.flush();
                }
            }
        }
        else {
            System.out.print("Please enter your lantern password:");
            System.out.flush();
            return LanternUtils.readPasswordCLI();
        }
    }
    
    
    private boolean unlockSettingsWithPassword(final char [] password)
        throws GeneralSecurityException, IOException {
        final boolean init = !localCipherProvider.isInitialized();
        localCipherProvider.feedUserInput(password, init);
        
        /*
        LanternHub.resetSettings(true);
        final SettingsState.State ss = LanternHub.settings().getSettings().getState();
        if (ss != SettingsState.State.SET) {
            log.error("Settings did not unlock, state is {}", ss);
            return false;
        }
        return true;
        */
        throw new UnsupportedOperationException("TODO");
    }
    
    private void loadLocalPasswordFile(final String pwFilename) {
        //final LocalCipherProvider lcp = localCipherProvider;
        if (!localCipherProvider.requiresAdditionalUserInput()) {
            log.error("Settings do not require a password to unlock.");
            System.exit(1);
        }

        if (StringUtils.isBlank(pwFilename)) {
            System.err.println("No filename specified to --{}");
            System.exit(1);
        }
        final File pwFile = new File(pwFilename);
        if (!(pwFile.exists() && pwFile.canRead())) {
            log.error("Unable to read password from {}", pwFilename);
            System.exit(1);
        }

        log.info("Reading local password from file \"{}\"", pwFilename);
        try {
            final String pw = FileUtils.readLines(pwFile, "US-ASCII").get(0);
            final boolean init = !localCipherProvider.isInitialized();
            localCipherProvider.feedUserInput(pw.toCharArray(), init);
        }
        catch (final IndexOutOfBoundsException e) {
            log.error("Password in file \"{}\" was incorrect", pwFilename);
            System.exit(1);
        }
        catch (final InvalidKeyException e) {
            log.error("Password in file \"{}\" was incorrect", pwFilename);
            System.exit(1);
        }
        catch (final GeneralSecurityException e) {
            log.error("Failed to initialize using password in file \"{}\": {}", 
                pwFilename, e);
            System.exit(1);
        }
        catch (final IOException e) {
            log.error("Failed to initialize using password in file \"{}\": {}", 
                pwFilename, e);
            System.exit(1);
        }
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
        log.info("Writing model!!");
        OutputStream os = null;
        try {
            final String json = LanternUtils.jsonify(toWrite, 
                Model.Persistent.class);
            //log.info("Writing JSON: \n{}", json);
            os = encryptedFileService.localEncryptOutputStream(this.modelFile);
            os.write(json.getBytes("UTF-8"));
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
        if (LanternConstants.ON_APP_ENGINE) {
            return;
        }
        write();
        /*
        SettingsState ss = settings().getSettings();
        if (ss.getState() == SettingsState.State.SET) {
            log.info("Writing settings");
            LanternHub.settingsIo().write(LanternHub.settings());
            log.info("Finished writing settings...");
        }
        else {
            log.warn("Not writing settings, state was {}", ss.getState());
        }
        */
    }
}
