package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.packet.Packet;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Default class for keeping track of which contacts are trusted.
 */
public class DefaultTrustedContactsManager implements TrustedContactsManager {

    private final static Logger log = 
        LoggerFactory.getLogger(DefaultTrustedContactsManager.class);
    
    private static final File CONTACTS_FILE =
        new File(LanternConstants.CONFIG_DIR, "trusted.txt");
    
    static {
        if (!CONTACTS_FILE.isFile()) {
            try {
                if (!CONTACTS_FILE.createNewFile()) {
                    log.error("Could not create trust file!!");
                } else {
                    CONTACTS_FILE.setWritable(true);
                }
            } catch (final IOException e) {
                log.error("Could not create trust file!!", e);
            }
        }
    }
    
    private final Set<String> trustedContacts;
    
    public DefaultTrustedContactsManager() {
        this.trustedContacts = loadTrustedContacts();
        log.info("Loaded contacts: {}", this.trustedContacts);
    }

    @Override
    public boolean isTrusted(final String email) {
        return trustedContacts.contains(email);
    }
    
    @Override
    public boolean isTrusted(final Packet msg) {
        return isJidTrusted(msg.getFrom());
    }

    private Set<String> loadTrustedContacts() {
        /*
        if (!CONTACTS_FILE.isFile()) {
            log.warn("No file to read!!");
            return Collections.emptySet();
        }
        log.info("Reading contacts...file size is: {}", CONTACTS_FILE.length());
        final Set<String> trusted = new HashSet<String>();
        BufferedReader br = null;
        try {
            final InputStream in = LanternUtils.localDecryptInputStream(CONTACTS_FILE);
            br = new BufferedReader(new InputStreamReader(in));
            String line = br.readLine();
            while (line != null) {
                log.info("Reading line: {}", line);
                if (StringUtils.isNotBlank(line)) {
                    trusted.add(line.trim());
                }
                line = br.readLine();
            }
            return trusted;
        } catch (final IOException e) {
            log.error("Reading error?", e);
        } catch (final GeneralSecurityException e) {
            log.error("Failed to decrypt: {}", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
        */
        return Collections.emptySet();
    }

    @Override
    public boolean isJidTrusted(final String jid) {
        final String email = XmppUtils.jidToUser(jid);
        return isTrusted(email);
    }

    
    @Override
    public void addTrustedContact(final String email) {
        log.info("Adding trusted contact: {}", email);
        addTrustedContacts(Arrays.asList(email));
    }
    
    @Override
    public void removeTrustedContact(final String email) {
        log.info("Removing trusted contact: {}", email);
        removeTrustedContacts(Arrays.asList(email));
    }
    
    @Override
    public void addTrustedContacts(final Collection<String> trusted) {
        trustedContacts.addAll(trusted);
        writeContacts();
    }

    @Override
    public void removeTrustedContacts(final Collection<String> trusted) {
        trustedContacts.removeAll(trusted);
        writeContacts();
    }

    @Override
    public void clearTrustedContacts() {
        trustedContacts.clear();
        CONTACTS_FILE.delete();
    }
    

    private void writeContacts() {
        /*
        synchronized (CONTACTS_FILE) {
            // We just write the whole thing again from scratch.
            CONTACTS_FILE.delete();
            OutputStreamWriter fw = null;
            try {
                OutputStream out =
                    LanternUtils.localEncryptOutputStream(CONTACTS_FILE);
                fw = new OutputStreamWriter(out);
                for (final String email : trustedContacts) {
                    final String newLine = email+"\n";
                    log.info("Adding contact line: {}", newLine);
                    fw.append(newLine);
                }
            } catch (final IOException e) {
                log.error("Could not write to contacts file?");
            } catch (final GeneralSecurityException e) {
                log.error("Failed to encrypt contacts file: {}", e);
            } finally {
                IOUtils.closeQuietly(fw);
            }
        }
        log.info("File size after writing: {}", CONTACTS_FILE.length());
        */
    }
}
