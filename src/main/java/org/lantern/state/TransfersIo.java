package org.lantern.state;

import java.io.File;
import java.util.Timer;
import java.util.TimerTask;

import org.lantern.LanternClientConstants;
import org.lantern.Stats;
import org.lantern.privacy.EncryptedFileService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class TransfersIo extends Storage<Transfers> {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final Stats tracker;

    /**
     * Creates a new instance with all the default operations.
     */
    @Inject
    public TransfersIo(final Stats tracker,
            final EncryptedFileService encryptedFileService, final Timer timer) {
        this(LanternClientConstants.DEFAULT_TRANSFERS_FILE,
               tracker, encryptedFileService, timer);
    }

    /**
     * Creates a new instance with custom settings typically used only in
     * testing.
     *
     * @param transfersFile
     *            The file where settings are stored.
     */
    public TransfersIo(final File transfersFile, final Stats tracker,
            final EncryptedFileService encryptedFileService, final Timer timer) {
        super(encryptedFileService, transfersFile, Transfers.class);
        this.tracker = tracker;
        obj = read();

        initSaveThread(timer);
    }

    @Override
    public Transfers read() {
        Transfers read;
        try {
            read = super.read();
        } catch (org.lantern.state.Storage.ModelReadFailedException e) {
            read = blank();
        }
        read.setStatsTracker(tracker);
        return read;
    }

    @Override
    protected Transfers blank() {
        log.info("Loading empty transfers!!");
        return new Transfers(tracker);
    }

    private void initSaveThread(Timer timer) {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                write();
            }
        }, 20000, 20000);
    }

}
