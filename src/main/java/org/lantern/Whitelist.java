package org.lantern;

import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpRequest;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.TreeSet;

import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.annotation.Keep;
import org.lantern.state.Model.Run;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * Keeps track of which domains are whitelisted.
 * </p>
 * 
 * <p>
 * The up-to-date whitelist is stored in {@link #whitelist}.
 * </p>
 * 
 * <p>
 * Default entries come from the files enumerated by {@link #WHITELISTS}. After
 * default entries are populated, the user has the ability to add/remove entries
 * from their whitelist. If a new default list is added to {@link #WHITELISTS},
 * all entries from that list will be added to the user's current whitelist.
 * This way, new version of Lantern can include updates to the whitelist while
 * still respecting the user's customizations from before.
 * </p>
 */
@Keep
public class Whitelist {

    private static final Logger log = LoggerFactory.getLogger(Whitelist.class);

    /**
     * Lists all the whitelists from src/main/resources/whitelist that are used
     * to populate default whitelist entries.  The order does not matter.
     */
    private static final String[] WHITELISTS = new String[] {
            "1.0.1.txt"
    };
    
    private static final String ORIGINAL_WHITELIST = "original.txt";
    
    private static final String[] DEFAULT_WHITELISTED_SITES;
    
    static {
        // Initialize DEFAULT_WHITELISTED_SITES
        Set<String> result = new HashSet<String>();
        try {
            result.addAll(readWhitelist(ORIGINAL_WHITELIST));
            for (String whitelist : WHITELISTS) {
                result.addAll(readWhitelist(whitelist));
            }
        } catch (Throwable t) {
            log.error("Unable to initialize DEFAULT_WHITELISTED_SITES");
        }
        DEFAULT_WHITELISTED_SITES = result.toArray(new String[0]);
    }
    

    /**
     * Returns a list of all default whitelisted domains.
     * 
     * @return
     */
    public static String[] getDefaultWhitelistedSites() {
        return DEFAULT_WHITELISTED_SITES;
    }
    
    private static Set<String> readWhitelist(String whitelistName) {
        Set<String> result = new HashSet<String>();
        ClassLoader cl = Whitelist.class.getClassLoader();
        String whitelistPath = "whitelists/" + whitelistName;
        BufferedReader reader = null;
        try {
            InputStream is = cl.getResourceAsStream(whitelistPath);
            reader = new BufferedReader(new InputStreamReader(is));
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (!StringUtils.isBlank(line)) {
                    if (!line.startsWith("#")) {
                        // Line has data and is not commented, create entry
                        result.add(line);
                    }
                }
            }
            return result;
        } catch (Throwable t) {
            log.warn("Unable to read whitelist {}", whitelistPath, t);
            return new HashSet<String>();
        } finally {
            try {
                reader.close();
            } catch (IOException ioe) {
                log.info("Unable to close whitelist reader", ioe);
            }
        }
    }

    /**
     * Keeps track of which whitelists from {@link #WHITELISTS} have been
     * applied to the overall whitelist.
     */
    private Set<String> appliedWhitelists = new HashSet<String>();

    /**
     * The overall whitelist.
     */
    private Collection<WhitelistEntry> whitelist =
            new TreeSet<WhitelistEntry>();

    /**
     * Applies the default entries from any whitelists that haven't been
     * recorded in appliedWhitelists yet.
     */
    public void applyDefaultEntries() {
        if (whitelist.isEmpty()) {
            // For empty whitelists, go ahead and apply the "original"
            // Not including "original" in the list of WHITELISTS helps us stay
            // backward compatible.
            applyWhitelist(ORIGINAL_WHITELIST);
        }
        for (String whitelistName : WHITELISTS) {
            if (!appliedWhitelists.contains(whitelistName)) {
                applyWhitelist(whitelistName);
            }
        }
    }
    
    private void applyWhitelist(String whitelistName) {
        ClassLoader cl = getClass().getClassLoader();
        String whitelistPath = "whitelists/" + whitelistName;
        BufferedReader reader = null;
        try {
            InputStream is = cl.getResourceAsStream(whitelistPath);
            reader = new BufferedReader(new InputStreamReader(is));
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (!StringUtils.isBlank(line)) {
                    if (!line.startsWith("#")) {
                        // Line has data and is not commented, create entry
                        this.whitelist.add(new WhitelistEntry(line,
                                true));
                    }
                }
            }
            appliedWhitelists.add(whitelistName);
            log.info("Applied whitelist {}", whitelistPath);
        } catch (Throwable t) {
            log.warn("Unable to apply whitelist {}", whitelistPath, t);
        }
    }

    public boolean isWhitelisted(final String uri,
            final Collection<WhitelistEntry> wl) {
        if (StringUtils.isBlank(uri)) {
            return false;
        }
        final String toMatch = normalized(toBaseUri(uri));
        return wl.contains(new WhitelistEntry(toMatch));
    }

    /**
     * Decides whether or not the specified full URI matches domains for our
     * whitelist.
     * 
     * @return <code>true</code> if the specified domain matches domains for our
     *         whitelist, otherwise <code>false</code>.
     */
    public boolean isWhitelisted(final String uri) {
        return isWhitelisted(uri, whitelist);
    }

    /**
     * Decides whether or not the specified HttpRequest is for a domain on our
     * whitelist. Note this also checks the Referer header.
     * 
     * @return <code>true</code> if the specified domain matches domains for our
     *         whitelist, otherwise <code>false</code>.
     */
    public boolean isWhitelisted(final HttpRequest request) {
        log.debug("Checking whitelist for request");
        final String uri = request.getUri();
        log.debug("URI is: {}", uri);
        final String referer = request.headers().get(HttpHeaders.Names.REFERER);
        return isWhitelisted(referer) || isWhitelisted(uri);
    }

    private String normalized(final String entry) {
        return entry.toLowerCase();
    }

    public void setStringEntries(final String[] entries) {
        setEntries(toEntries(entries));
    }

    private Collection<WhitelistEntry> toEntries(final String[] entries) {
        final Collection<WhitelistEntry> wl = new TreeSet<WhitelistEntry>();
        for (final String entry : entries) {
            wl.add(new WhitelistEntry(normalized(entry)));
        }
        return wl;
    }

    public void addEntry(final String entry) {
        log.debug("Adding whitelist entry: {}", entry);
        whitelist.add(new WhitelistEntry(normalized(entry)));
    }

    public void removeEntry(final String entry) {
        final String normalized = normalized(entry);
        whitelist.remove(new WhitelistEntry(normalized));
    }

    public Collection<WhitelistEntry> getEntries() {
        return new TreeSet<WhitelistEntry>(whitelist);
    }

    public void setEntries(final Collection<WhitelistEntry> entries) {
        this.whitelist = entries;
    }
    
    public Set<String> getAppliedWhitelists() {
        return appliedWhitelists;
    }
    
    public void setAppliedWhitelists(Set<String> appliedWhitelists) {
        this.appliedWhitelists = appliedWhitelists;
    }

    private String toBaseUri(final String uri) {
        log.debug("Parsing full URI: {}", uri);
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
        log.debug("base uri: " + base);

        // http://html5pattern.com/ - changed slightly
        // just in case there is a port following
        if (base.matches("((^|\\.)((25[0-5])|(2[0-4]\\d)|(1\\d\\d)|([1-9]?\\d))){4}:?(.*)?$")) {
            log.debug("uri is an ip address");
            String toMatch = base;
            if (base.contains(":")) {
                toMatch = StringUtils.substringBefore(toMatch, ":");
            }
            return toMatch;
        } else {
            String domainExtension = StringUtils.substringAfterLast(base, ".");

            // Make sure we strip alternative ports, like 443.
            if (domainExtension.contains(":")) {
                domainExtension = StringUtils.substringBefore(domainExtension,
                        ":");
            }
            String domain = StringUtils.substringBeforeLast(base, ".");
            log.debug("Domain: {}", domain);
            final String[] majorTlds = { "com", "org", "net" };
            for (final String tld : majorTlds) {
                if (domain.endsWith("." + tld)) {
                    domain = StringUtils.substringBeforeLast(domain, "." + tld);
                    domainExtension = tld + "." + domainExtension;
                    log.debug("Domain: {}", domain);
                    log.debug("domainExtension: {}", domainExtension);
                    break;
                }
            }

            final String toMatchBase;
            if (domain.contains(".")) {
                toMatchBase = StringUtils.substringAfterLast(domain, ".");
            } else {
                toMatchBase = domain;
            }
            final String toMatch = toMatchBase + "." + domainExtension;
            log.debug("Matching against: {}", toMatch);
            return toMatch;
        }
    }

    @JsonView({ Run.class })
    public Collection<String> getEntriesAsStrings() {
        final Collection<WhitelistEntry> entries = getEntries();
        final Collection<String> parsed =
                new TreeSet<String>(String.CASE_INSENSITIVE_ORDER);
        for (final WhitelistEntry entry : entries) {
            final String str = entry.getSite();
            parsed.add(str);
        }
        return parsed;
    }

    public void reset() {
        // these domains host required services and can't be removed
        whitelist.clear();
        appliedWhitelists.clear();
        applyDefaultEntries();
    }
}
