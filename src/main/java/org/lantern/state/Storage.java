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
import org.lantern.LanternConstants;
import org.lantern.Shutdownable;
import org.lantern.privacy.EncryptedFileService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;
import com.google.inject.Provider;

public abstract class Storage<T> implements Provider<T>, Shutdownable {

    private final Logger log = LoggerFactory.getLogger(getClass());

    protected final EncryptedFileService encryptedFileService;

    T obj;

    private final File file;
    private final File newFile;

    private final Class<T> cls;

    Storage(final EncryptedFileService encryptedFileService, File file, Class<T> cls) {
        this.cls = cls;
        this.encryptedFileService = encryptedFileService;
        this.file = file;
        this.newFile = new File(file.getAbsolutePath() + ".new");
    }

    protected abstract T blank();

    @Override
    public T get() {
        return this.obj;
    }

    public synchronized void write(final T toWrite) {
        if (LanternConstants.ON_APP_ENGINE) {
            log.debug("Not writing on app engine");
            return;
        }
        log.debug("Writing!");
        OutputStream os = null;
        try {

            final String json = JsonUtils.jsonify(toWrite,
                    Model.Persistent.class);
            // log.info("Writing JSON: \n{}", json);
            os = encryptedFileService
                    .localEncryptOutputStream(this.newFile);
            os.write(json.getBytes("UTF-8"));
            IOUtils.closeQuietly(os);

            Files.move(newFile, file);
        } catch (final IOException e) {
            log.error("Error encrypting stream", e);
        } catch (final GeneralSecurityException e) {
            log.error("Error encrypting stream", e);
        }
    }

    static class ModelReadFailedException extends Exception {
        private static final long serialVersionUID = 6572676909676411690L;
    }

    /**
     * Reads the object from disk.
     *
     * @return The object instance as read from disk.
     */
    public T read() throws ModelReadFailedException {
        if (!file.isFile()) {
            return blank();
        }
        final ObjectMapper mapper = new ObjectMapper();
        InputStream is = null;
        try {
            is = encryptedFileService.localDecryptInputStream(file);
            final String json = IOUtils.toString(is, "UTF-8");
            if (StringUtils.isBlank(json) || json.equalsIgnoreCase("null")) {
                log.info("Can't build object from empty string");
                return blank();
            }
            final T read = mapper.readValue(json, cls);
            return read;
        } catch (final IOException e) {
            log.error("Could not read object", e);
        } catch (final GeneralSecurityException e) {
            log.error("Security error?", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        throw new ModelReadFailedException();
    }

    @Override
    public void stop() {
        write();
    }


    /**
     * Serializes the current object.
     */
    public void write() {
        write(this.obj);
    }

}
