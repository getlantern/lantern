package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.GeneralSecurityException;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.JsonUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.Shutdownable;
import org.lantern.StatsTracker;
import org.lantern.privacy.EncryptedFileService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;
import com.google.inject.Inject;
import com.google.inject.Provider;
import com.google.inject.Singleton;

@Singleton
public class TransfersIo implements Provider<Transfers>, Shutdownable {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final File transfersFile;
    private final File newTransfersFile;

    private final Transfers transfers;

    private final EncryptedFileService encryptedFileService;

    private final StatsTracker tracker;

    /**
     * Creates a new instance with all the default operations.
     */
    @Inject
    public TransfersIo(final StatsTracker tracker,
            final EncryptedFileService encryptedFileService,
            final Timer timer) {
        this(LanternClientConstants.DEFAULT_TRANSFERS_FILE,
                encryptedFileService, tracker, timer);
    }

    /**
     * Creates a new instance with custom settings typically used only in
     * testing.
     *
     * @param transfersFile
     *            The file where settings are stored.
     */
    public TransfersIo(final File transfersFile,
            final EncryptedFileService encryptedFileService,
            final StatsTracker tracker, final Timer timer) {
        this.transfersFile = transfersFile;
        this.newTransfersFile = new File(transfersFile.getAbsolutePath() + ".new");
        this.encryptedFileService = encryptedFileService;
        this.tracker = tracker;
        this.transfers = read();
        initSaveThread(timer);
        log.info("Loaded module");
    }

    private void initSaveThread(Timer timer) {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                write();
            }
        }, 20000, 20000);
    }

    @Override
    public Transfers get() {
        return this.transfers;
    }

    /**
     * Reads the state transfers from disk.
     *
     * @return The {@link transfers} instance as read from disk.
     */
    public Transfers read() {
        if (!transfersFile.isFile()) {
            return blankTransfers();
        }
        final ObjectMapper mapper = new ObjectMapper();
        InputStream is = null;
        try {
            is = encryptedFileService.localDecryptInputStream(transfersFile);
            final String json = IOUtils.toString(is);
            if (StringUtils.isBlank(json) || json.equalsIgnoreCase("null")) {
                log.info("Can't build settings from empty string");
                return blankTransfers();
            }
            final Transfers read = mapper.readValue(json, Transfers.class);
            read.setStatsTracker(tracker);
            return read;
        } catch (final IOException e) {
            log.error("Could not read transfers", e);
        } catch (final GeneralSecurityException e) {
            log.error("Security error?", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        final Transfers transfers = blankTransfers();
        return transfers;
    }

    private Transfers blankTransfers() {
        log.info("Loading empty transfers!!");
        return new Transfers(tracker);
    }

    /**
     * Serializes the current transfers.
     */
    public void write() {
        write(this.transfers);
    }

    /**
     * Serializes the specified transfers -- useful for testing.
     */
    public void write(final Transfers toWrite) {
        if (LanternConstants.ON_APP_ENGINE) {
            log.debug("Not writing on app engine");
            return;
        }
        log.debug("Writing transfers!!");
        OutputStream os = null;
        try {

            final String json = JsonUtils.jsonify(toWrite,
                    Model.Persistent.class);
            // log.info("Writing JSON: \n{}", json);
            os = encryptedFileService
                    .localEncryptOutputStream(this.newTransfersFile);
            os.write(json.getBytes("UTF-8"));
            IOUtils.closeQuietly(os);

            Files.move(newTransfersFile, transfersFile);
        } catch (final IOException e) {
            log.error("Error encrypting stream", e);
        } catch (final GeneralSecurityException e) {
            log.error("Error encrypting stream", e);
        }
    }

    @Override
    public void stop() {
        write();
    }
}
