package org.lantern.privacy;

import java.io.File;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import org.apache.commons.codec.binary.Base64;
import org.freedesktop.Secret.Collection;
import org.freedesktop.Secret.Item;
import org.freedesktop.Secret.Pair;
import org.freedesktop.Secret.Prompt;
import org.freedesktop.Secret.Secret;
import org.freedesktop.Secret.Service;
import org.freedesktop.Secret.Session;
import org.freedesktop.dbus.DBusConnection;
import org.freedesktop.dbus.DBusSigHandler;
import org.freedesktop.dbus.DBusSignal;
import org.freedesktop.dbus.Path;
import org.freedesktop.dbus.Variant;
import org.freedesktop.dbus.exceptions.DBusException;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * SecretServiceLocalCipherProvider
 *
 * This is a LocalCipherProvider that uses
 * the DBUS "Secret Service" API to store a local key
 * used to encrypt/decrypt local data.
 *
 */
public class SecretServiceLocalCipherProvider extends AbstractAESLocalCipherProvider {

    private static final String BUS_NAME = "org.freedesktop.secrets";
    private static final String SERVICE_PATH = "/org/freedesktop/secrets";
    private static final String ALGORITHM_PLAIN = "plain";
    private static final String COLLECTION_PATH = "/org/freedesktop/secrets/aliases/default";
    private static final String NO_OBJECT = "/";
    private static final String SECRET_LABEL_PROPERTY = "org.freedesktop.Secret.Item.Label";
    private static final String SECRET_ATTRIBUTES_PROPERTY = "org.freedesktop.Secret.Item.Attributes";
    private static final String SECRET_ATTR_NAME = "lanternId";
    private static final String SECRET_ATTR_VALUE = "org.lantern.SecretServiceLocalCipherProvider";
    private static final String LANTERN_KEY_LABEL = "Lantern Local Privacy";
    private static final String SECRET_CONTENT_TYPE = "text/plain; charset=utf8";

    private static final Logger LOG = LoggerFactory.getLogger(SecretServiceLocalCipherProvider.class);

    public SecretServiceLocalCipherProvider() {
        super();
    }

    public SecretServiceLocalCipherProvider(final File validatorFile, final File cipherParamsFile) {
        super(validatorFile, cipherParamsFile);
    }

    public static boolean secretServiceAvailable() {
        DBusConnection conn = null;
        try {
            LOG.debug("Checking for Secret Service API availability...");
            conn = DBusConnection.getConnection(DBusConnection.SESSION);
            final Service secretService = conn.getRemoteObject(
                BUS_NAME, SERVICE_PATH, Service.class);
            final Pair<Variant, Path> result = 
                secretService.OpenSession(ALGORITHM_PLAIN, new Variant(""));
            if (NO_OBJECT.equals(result.b.getPath())) {
                LOG.info("Failed to negotiate plain session with Secret Service API.");
                return false;
            }
            else {
                final Session session = conn.getRemoteObject(
                    BUS_NAME, result.b.getPath(), Session.class);
                session.Close();
            }
            
            LOG.debug("Found Secret Service API.");
            return true;
        } catch (final Exception e) {
            LOG.debug("Could not connect to Secret Service API at:"+SERVICE_PATH, e);
            return false;
        } catch (final UnsatisfiedLinkError error) {
            if (LanternUtils.isDevMode()) {
                LOG.error("Could not load so file? Testing?", error);
                return false;
            } else {
                LOG.error("CAN'T HAVE UNENCRYPTED FILES IN PRODUCTION!!");
                System.exit(1);
                return false;
            }
        } finally {
            closeConnection(conn);
        }
    }

    private static void closeConnection(final DBusConnection conn) {
        if (conn != null) {
            try {
                conn.disconnect();
            } catch (Exception e) {
                LOG.error("Error closing DBus connection {}", e);
            }
        }
    }

    @Override
    byte[] loadKeyData() throws IOException, GeneralSecurityException {
        DBusConnection conn = null;
        byte [] encodedKey = null;
        try {
            LOG.debug("Loading key data from Secret Service API...");

            conn = DBusConnection.getConnection(DBusConnection.SESSION);
            final Service secretService = conn.getRemoteObject(
                BUS_NAME, SERVICE_PATH, Service.class);

            // negotiate a "plain" session (no encryption)
            final Pair<Variant, Path> result = secretService.OpenSession(ALGORITHM_PLAIN, new Variant(""));
            if (NO_OBJECT.equals(result.b.getPath())) {
                throw new IOException("Unable to negotiate DBus session!");
            }
            final Path sessionPath = result.b;
            final Session session = conn.getRemoteObject(BUS_NAME, sessionPath.getPath(), Session.class);

            LOG.debug("Requesting Item....");
            final Map<String, String> secretAttrs = new HashMap<String, String>();
            secretAttrs.put(SECRET_ATTR_NAME,
                            SECRET_ATTR_VALUE);
            final Pair<List<Path>, List<Path>> items = secretService.SearchItems(secretAttrs);
            LOG.debug("Got {} unlocked / {} locked secret items.", items.a.size(), items.b.size());

            Item secretItem = null;
            if (items.a.isEmpty()) {
                if (items.b.isEmpty()) {
                    LOG.debug("Secret item is missing!");
                    throw new GeneralSecurityException("Unable to locate secret in keychain!");
                }
                else {
                    LOG.debug("Secret is locked! Attempting to unlock...");
                    final Path secretItemPath = items.b.get(0);
                    if (unlockPath(secretItemPath, secretService, conn)) {
                        LOG.debug("Assuming all is well using path {}...", secretItemPath.getPath());
                        secretItem = conn.getRemoteObject(BUS_NAME, secretItemPath.getPath(), Item.class);
                    }
                    else {
                        LOG.error("Failed to unlock lantern keychain item.");
                        throw new GeneralSecurityException("Failed to unlock lantern keychain item.");
                    }
                }
            }
            else {
                LOG.debug("Secret is unlocked...");
                final Path itemPath = items.a.get(0);
                secretItem = conn.getRemoteObject(BUS_NAME, itemPath.getPath(), Item.class);
            }
            final Secret secret = secretItem.GetSecret(sessionPath);
            encodedKey = new byte[secret.value.size()];
            int i = 0;
            for (final Byte b : secret.value) {
                encodedKey[i++] = b;
            }
            session.Close();

            final Base64 base64 = new Base64();
            return base64.decode(encodedKey);
        } catch (DBusException e) {
            throw new IOException(e);
        } catch (InterruptedException e) {
            throw new IOException(e);
        }finally {
            if (encodedKey != null) {
                Arrays.fill(encodedKey, (byte) 0);
            }
            closeConnection(conn);
        }
    }

    @Override
    void storeKeyData(final byte[] key) throws IOException, GeneralSecurityException {
        byte [] encodedKey = null;
        List<Byte> secretValue = null;

        DBusConnection conn = null;
        try {
            LOG.debug("Storing key data via Secret Service API...");
            conn = DBusConnection.getConnection(DBusConnection.SESSION);
            final Service secretService = conn.getRemoteObject(
                BUS_NAME, SERVICE_PATH, Service.class);

            final Collection collection = conn.getRemoteObject(
                BUS_NAME, COLLECTION_PATH, Collection.class);

            // Collection properties do not seem to be implemented...
            // So instead of checking, just request an unlock in all cases
            if (!unlockPath(new Path(COLLECTION_PATH), secretService, conn)) {
                throw new GeneralSecurityException("Unable to unlock secret collection.");
            }

            // negotiate a "plain" session (no encryption)
            final Pair<Variant, Path> result = secretService.OpenSession(ALGORITHM_PLAIN, new Variant(""));
            if (NO_OBJECT.equals(result.b.getPath())) {
                throw new IOException("Unable to negotiate DBus session!");
            }
            final Path sessionPath = result.b;
            final Session session = conn.getRemoteObject(
                BUS_NAME, sessionPath.getPath(), Session.class);

            // construct a "Secret"
            final Base64 base64 = new Base64();
            encodedKey = base64.encode(key);
            secretValue = new ArrayList<Byte>(encodedKey.length);
            for (byte b : encodedKey) {
                secretValue.add(b);
            }
            final Secret secret = new Secret(sessionPath, new ArrayList<Byte>(), secretValue, SECRET_CONTENT_TYPE);
            final Map<String, Variant> secretProps = new HashMap<String, Variant>();
            secretProps.put(SECRET_LABEL_PROPERTY,
                            new Variant(LANTERN_KEY_LABEL));

            // these are the "attributes" of the item, not to be confused
            // with properties...
            final Map<String, String> secretAttrs = new HashMap<String, String>();
            secretAttrs.put(SECRET_ATTR_NAME, SECRET_ATTR_VALUE);
            secretProps.put(SECRET_ATTRIBUTES_PROPERTY, new Variant(secretAttrs, "a{ss}"));

            // add the item to the collection...
            LOG.debug("Requesting CreateItem....");
            final Pair<Path, Path> createResult = collection.CreateItem(
                secretProps, secret, true);

            final Path promptPath = createResult.b;

            // user may need to be prompted... for what is unclear.
            if (!NO_OBJECT.equals(promptPath.getPath())) {
                Prompt.Completed sig = prompt(promptPath, conn);
                // there does not seem to be a specification of what this means in this case... ?
                // possibly the path to the item or / on failure?
                LOG.debug("Prompt completed with dismissed={} result={}", sig.dismissed, sig.result);
                final List<Path> createdItemPaths = (List<Path>) sig.result.getValue();
                Path createdItemPath = null;
                if (createdItemPaths.size() > 0 ) {
                    createdItemPath = createdItemPaths.get(0);
                }
                if (sig.dismissed == true || createdItemPath == null || NO_OBJECT.equals(createdItemPath.getPath())) {
                    LOG.error("Failed to create lantern keychain item.");
                    throw new GeneralSecurityException("Failed to create lantern keychain item.");
                }
            }
            else {
                LOG.debug("No prompt requested.");
            }

            session.Close();
            LOG.debug("Finished storing key in Secret Service API...");
        } catch (DBusException e) {
            throw new IOException(e);
        } catch (InterruptedException e) {
            throw new IOException(e);
        } finally {
            if (encodedKey != null) {
                Arrays.fill(encodedKey, (byte) 0);
            }
            closeConnection(conn);
        }
    }

    private boolean unlockPath(final Path path, final Service secretService, final DBusConnection conn)
        throws DBusException, InterruptedException {
        LOG.debug("Requesting unlock of path {}", path.getPath());
        final List<Path> pathsToUnlock = new ArrayList<Path>(1);
        pathsToUnlock.add(path);
        final Pair<List<Path>, Path> unlockResult = secretService.Unlock(pathsToUnlock);
        if (unlockResult.a.size() > 0) {
            LOG.debug("Path unlocked without prompt...");
            return true;
        }
        // if there is a prompt
        else if (!NO_OBJECT.equals(unlockResult.b.getPath())) {
            LOG.debug("Prompting user to unlock....");
            Prompt.Completed sig = prompt(unlockResult.b, conn);
            LOG.debug("Prompt completed with dismissed={} result={}", sig.dismissed, sig.result);
            final List<Path> unlockedPaths = (List<Path>) sig.result.getValue();
            Path unlockedPath = null;
            if (unlockedPaths.size() > 0) {
                unlockedPath = unlockedPaths.get(0);
            }
            if (sig.dismissed == true || unlockedPath == null || NO_OBJECT.equals(unlockedPath.getPath())) {
                LOG.error("Failed to unlock path {}", path.getPath());
                return false;
            }
            else {
                return true;
            }
        }
        else {
            LOG.debug("Confused, no prompt and no unlocked objects, failing.");
            return false;
        }
    }

    private Prompt.Completed prompt(final Path promptPath, final DBusConnection conn)
        throws InterruptedException, DBusException {
        LOG.debug("Prompt required...");
        final Prompt prompt = conn.getRemoteObject(
            BUS_NAME, promptPath.getPath(), Prompt.class);

        final PromptHandler handler = new PromptHandler();
        conn.addSigHandler(Prompt.Completed.class, prompt, handler);
        LOG.debug("added signal handler, calling prompt");
        try {
            prompt.Prompt("0"); // XXX window-id ?
            LOG.debug("Waiting for prompt to complete...");
            return handler.await();
        } finally {
            conn.removeSigHandler(Prompt.Completed.class, prompt, handler);
        }
    }

    /**
     * This is a DBusSigHandler that waits for the
     * response to a user prompt by sitting on a
     * Condition variable.
     */
    private class PromptHandler implements DBusSigHandler {

        private final Lock lock;
        private final Condition gotResult;
        private DBusSignal sig = null;

        public PromptHandler() {
            lock = new ReentrantLock();
            gotResult = lock.newCondition();
        }

        @Override
        public void handle(final DBusSignal sig) {
            this.sig = sig;
            lock.lock();
            try {
                gotResult.signal();
            } finally {
                lock.unlock();
            }
        }

        public Prompt.Completed await() throws InterruptedException {
            lock.lock();
            try {
                while (sig == null) {
                    gotResult.await();
                }
                return (Prompt.Completed) sig;
            } finally {
                lock.unlock();
            }
        }
    }
}