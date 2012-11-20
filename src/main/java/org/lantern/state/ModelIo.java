package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.map.SerializationConfig;
import org.codehaus.jackson.map.SerializationConfig.Feature;
import org.lantern.LanternConstants;
import org.lantern.LanternHub;
import org.lantern.LanternUtils;
import org.lantern.privacy.UserInputRequiredException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ModelIo {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File modelFile;

    private final Model model;
    
    /**
     * Creates a new instance with all the default operations.
     */
    public ModelIo() {
        this(LanternConstants.DEFAULT_MODEL_FILE);
    }
    
    
    /**
     * Creates a new instance with custom settings typically used only in 
     * testing.
     * 
     * @param modelFile The file where settings are stored.
     */
    public ModelIo(final File modelFile) {
        this.modelFile = modelFile;
        this.model = read();
        if (!LanternConstants.ON_APP_ENGINE) {
            // Save the most current state when exiting.
            Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
    
                @Override
                public void run() {
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
                
            }, "Write-Model-Thread"));
        }
    }

    /**
     * Reads the state model from disk.
     * 
     * @return The {@link Model} instance as read from disk.
     */
    private Model read() {
        if (!modelFile.isFile()) {
            return blankModel();
        }
        final ObjectMapper mapper = new ObjectMapper();
        //mapper.configure(Feature.FAIL_ON_EMPTY_BEANS, false);
        InputStream is = null;
        try {
            is = LanternUtils.localDecryptInputStream(modelFile);
            final String json = IOUtils.toString(is);
            log.info("Building setting from json string...");
            if (StringUtils.isBlank(json) || json.equalsIgnoreCase("null")) {
                log.info("Can't build settings from empty string");
                return blankModel();
            }
            final Model read = mapper.readValue(json, Model.class);
            log.info("Built settings from disk: {}", read);
            /*
            if (StringUtils.isBlank(read.getPassword())) {
                read.setPassword(read.getStoredPassword());
            }
            */
            //read.getSettings().setState(State.SET); // read successfully.
            return read;
        } catch (final UserInputRequiredException e) {
            log.info("Settings require password to be unlocked.");
            return blankModel();
        } catch (final IOException e) {
            log.error("Could not read model", e);
        } catch (final GeneralSecurityException e) {
            log.error("Could not read model", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        final Model settings = blankModel();
        //final SettingsState ss = settings.getSettings();
        //ss.setState(State.CORRUPTED);
        //ss.setMessage("Could not read settings file.");
        settings.setModal(Modal.settingsLoadFailure);
        return settings;
    }
    

    private Model blankModel() {
        log.info("Loading empty model!!");
        final Model blank = new Model();//new Model(new Whitelist());
        
        // if some password initialization is required, 
        // consider the settings to be "locked"
        if (LanternHub.localCipherProvider().requiresAdditionalUserInput()) {
            //s.getSettings().setState(State.LOCKED);
            blank.setModal(Modal.authorize);
        }
        // otherwise, consider new settings to have been successfully loaded
        else {
            //s.getSettings().setState(State.SET);
        }
        return blank;
    }
    
    /**
     * Serializing the current model.
     */
    public void write() {
        OutputStream os = null;
        try {
            final String json = LanternUtils.jsonify(model, 
                Model.Persistent.class);
            os = LanternUtils.localEncryptOutputStream(this.modelFile);
            os.write(json.getBytes("UTF-8"));
        } catch (final IOException e) {
            log.error("Error encrypting stream", e);
        } catch (final GeneralSecurityException e) {
            log.error("Error encrypting stream", e);
        } finally {
            IOUtils.closeQuietly(os);
        }
    }


    public Model getModel() {
        return model;
    }
}
