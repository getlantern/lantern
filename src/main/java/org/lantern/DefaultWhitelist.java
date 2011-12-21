package org.lantern;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.security.GeneralSecurityException;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.TreeSet;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Keeps track of which domains are whitelisted and persists them to disk.
 */
public class DefaultWhitelist implements Whitelist {

    private final Logger LOG = LoggerFactory.getLogger(DefaultWhitelist.class);
    
    private final String WHITELIST_NAME = "whitelist.txt";
    private final String REPORTED_WHITELIST_NAME = 
        "reportedWhitelist.txt";
    
    private final File WHITELIST_FILE = 
        new File(LanternUtils.configDir(), WHITELIST_NAME);
    private final File REPORTED_WHITELIST_FILE = 
        new File(LanternUtils.configDir(), REPORTED_WHITELIST_NAME);

    {
        buildWhitelists();
    }    
    
    private Collection<WhitelistEntry> whitelist;
    private Collection<WhitelistEntry> lastReportedWhitelist;
    

    @Override
    public void reset() {
        WHITELIST_FILE.delete();
        REPORTED_WHITELIST_FILE.delete();
        buildWhitelists();
    }
    
    private void buildWhitelists() {
        final File original = new File(WHITELIST_NAME);
        if (!WHITELIST_FILE.isFile() || 
            FileUtils.isFileNewer(original, WHITELIST_FILE)) {
            try {
                LanternUtils.localEncryptedCopy(original, WHITELIST_FILE);
            } catch (final IOException e) {
                LOG.error("Could not copy original whitelist?", e);
            } catch (final GeneralSecurityException e) {
                LOG.error("Could not encrypt original whitelist", e);
            }
        }
        if (!REPORTED_WHITELIST_FILE.isFile()) {
            try {
                LanternUtils.localEncryptedCopy(original, REPORTED_WHITELIST_FILE);
            } catch (final IOException e) {
                LOG.error("Could not create reported whitelist file?", e);
            } catch (final GeneralSecurityException e) {
                LOG.error("Could not encrypt copy of reported whitelist", e);
            }
        }
        refreshFromFiles();
        whitelist.add(new WhitelistEntry("getlantern.org", true));
        whitelist.add(new WhitelistEntry("getexceptional.com", true));
    }

    private void refreshFromFiles() {
        whitelist = buildWhitelist(WHITELIST_FILE);
        lastReportedWhitelist = buildWhitelist(REPORTED_WHITELIST_FILE);
    }

    @Override
    public boolean isWhitelisted(final String uri,
        final Collection<WhitelistEntry> wl) {
        final String toMatch = toBaseUri(uri);
        return wl.contains(new WhitelistEntry(toMatch));
    }
    
    private String toBaseUri(final String uri) {
        LOG.info("Parsing full URI: {}", uri);
        final String afterHttp;
        if (!uri.startsWith("http")) {
            afterHttp = uri;
        } else {
            afterHttp = StringUtils.substringAfter(uri, "://");
        }
        final String base;
        if (afterHttp.contains("/")) {
            base = StringUtils.substringBefore(afterHttp, "/");
        } else {
            base = afterHttp;
        }
        String domainExtension = StringUtils.substringAfterLast(base, ".");
        
        // Make sure we strip alternative ports, like 443.
        if (domainExtension.contains(":")) {
            domainExtension = StringUtils.substringBefore(domainExtension, ":");
        }
        final String domain = StringUtils.substringBeforeLast(base, ".");
        final String toMatchBase;
        if (domain.contains(".")) {
            toMatchBase = StringUtils.substringAfterLast(domain, ".");
        } else {
            toMatchBase = domain;
        }
        final String toMatch = toMatchBase + "." + domainExtension;
        LOG.info("Matching against: {}", toMatch);
        return toMatch;
    }
    
    /**
     * Decides whether or not the specified full URI matches domains for our
     * whitelist.
     * 
     * @return <code>true</code> if the specified domain matches domains for
     * our whitelist, otherwise false.
     */
    @Override
    public boolean isWhitelisted(final String uri) {
        LOG.info("Parsing full URI: {}", uri);
        return isWhitelisted(uri, whitelist);
    }
    
    @Override
    public boolean isWhitelisted(final HttpRequest request) {
        LOG.info("Checking whitelist for request");
        final String uri = request.getUri();
        LOG.info("URI is: {}", uri);

        final String referer = request.getHeader("referer");
        
        final String uriToCheck;
        LOG.info("Referer: "+referer);
        if (!StringUtils.isBlank(referer)) {
            uriToCheck = referer;
        } else {
            uriToCheck = uri;
        }

        return isWhitelisted(uriToCheck);
    }
    
    @Override
    public void addEntry(final String entry) {
        whitelist.add(new WhitelistEntry(entry));
        write(whitelist, WHITELIST_FILE);
    }
    
    private void write(final Collection<WhitelistEntry> entries, 
        final File file) {
        BufferedWriter bw = null;
        try {
            final OutputStream eos = LanternUtils.localEncryptOutputStream(file);
            bw = new BufferedWriter(new OutputStreamWriter(eos));
            for (final WhitelistEntry entry: entries) {
                bw.write(entry.getSite());
                bw.write("\n");
            }
        } catch (final IOException e) {
            LOG.error("Could not read file");
        } catch (final GeneralSecurityException e) {
            LOG.error("Could not encrypt file", e);
        } finally {
            IOUtils.closeQuietly(bw);
        }
    }

    @Override
    public void removeEntry(final String entry) {
        whitelist.remove(new WhitelistEntry(entry));
        write(whitelist, WHITELIST_FILE);
    }
    
    @Override
    public Collection<WhitelistEntry> getAdditions() {
        final Collection<WhitelistEntry> additions = 
            new LinkedHashSet<WhitelistEntry>();
        synchronized (whitelist) {
            synchronized (lastReportedWhitelist) {
                for (final WhitelistEntry entry : whitelist) {
                    if (!lastReportedWhitelist.contains(entry)) {
                        additions.add(entry);
                    }
                }
            }
        }
        return additions;
    }
    
    @Override
    public Collection<WhitelistEntry> getRemovals() {
        final Collection<WhitelistEntry> removals = 
            new LinkedHashSet<WhitelistEntry>();
        synchronized (whitelist) {
            synchronized (lastReportedWhitelist) {
                for (final WhitelistEntry entry : lastReportedWhitelist) {
                    if (!whitelist.contains(entry)) {
                        removals.add(entry);
                    }
                }
            }
        }
        return removals;
    }
    
    @Override
    public String getAdditionsAsJson() {
        return LanternUtils.jsonify(getAdditions());
    }

    @Override
    public String getRemovalsAsJson() {
        return LanternUtils.jsonify(getRemovals());
    }
    
    private Collection<WhitelistEntry> buildWhitelist(final File file) {
        LOG.info("Processing whitelist file: {}", file);
        final Collection<WhitelistEntry> wl = new HashSet<WhitelistEntry>();
        BufferedReader br = null;
        try {
            final InputStream ein = 
                LanternUtils.localDecryptInputStream(file);
            br = new BufferedReader(new InputStreamReader(ein));
            String site = br.readLine();
            while (site != null) {
                site = site.trim();
                //LOG.info("Processing whitelist line: {}", site);
                if (StringUtils.isNotBlank(site)) {
                    // Ignore commented-out sites.
                    if (!site.startsWith("#")) {
                        wl.add(new WhitelistEntry(site));
                    }
                }
                site = br.readLine();
            }
        } catch (final FileNotFoundException e) {
            LOG.error("Could not find whitelist file!!", e);
        } catch (final IOException e) {
            LOG.error("Could not read whitelist file", e);
        } catch (final GeneralSecurityException e) {
            LOG.error("Could not decrypt whitelist file", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
        return wl;
    }

    @Override
    public void whitelistReported() {
        // We basically need to copy the current whitelist to be the last
        // reported whitelist.
        try {
            // these are already encrypted, so nothing special here...
            FileUtils.copyFile(WHITELIST_FILE, REPORTED_WHITELIST_FILE);
        } catch (final IOException e) {
            LOG.error("Could not copy whitelist file?");
        }
        refreshFromFiles();
    }
    
    @Override
    public Collection<WhitelistEntry> getWhitelist() {
        synchronized (whitelist) {
            return new TreeSet<WhitelistEntry>(whitelist);
        }
    }
}
