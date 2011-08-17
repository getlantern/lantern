package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DefaultTrustedContactsManager implements TrustedContactsManager {

    private final static Logger log = 
        LoggerFactory.getLogger(DefaultTrustedContactsManager.class);
    
    private static final File CONTACTS_FILE =
        new File(LanternUtils.configDir(), "trusted.txt");
    
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
    public void addTrustedContact(final String email) {
        log.info("Adding trusted contact: {}", email);
        addTrustedContacts(Arrays.asList(email));
    }

    @Override
    public boolean isTrusted(final String email) {
        return trustedContacts.contains(email);
    }
    

    private Set<String> loadTrustedContacts() {
        if (!CONTACTS_FILE.isFile()) {
            log.warn("No file to read!!");
            return Collections.emptySet();
        }
        log.info("Reading contacts...file size is: {}", CONTACTS_FILE.length());
        final Set<String> trusted = new HashSet<String>();
        BufferedReader br = null;
        try {
            br = new BufferedReader(new FileReader(CONTACTS_FILE));
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
        } finally {
            IOUtils.closeQuietly(br);
        }
        return Collections.emptySet();
    }

    @Override
    public boolean isJidTrusted(final String jid) {
        final String email = LanternUtils.jidToUser(jid);
        return isTrusted(email);
    }

    @Override
    public void addTrustedContacts(final Collection<String> trusted) {
        trustedContacts.addAll(trusted);
        synchronized (CONTACTS_FILE) {
            FileWriter fw = null;
            try {
                fw = new FileWriter(CONTACTS_FILE);
                for (final String email : trusted) {
                    final String newLine = email+"\n";
                    log.info("Adding contact line: {}", newLine);
                    fw.append(newLine);
                }
            } catch (final IOException e) {
                log.error("Could not write to contacts file?");
            } finally {
                IOUtils.closeQuietly(fw);
            }
        }
        log.info("File size after writing: {}", CONTACTS_FILE.length());
    }
}
