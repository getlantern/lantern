package org.lantern;

import java.util.Collection;
import java.util.HashSet;
import java.util.TreeSet;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Keeps track of which domains are whitelisted.
 */
public class Whitelist {

    private final Logger log = LoggerFactory.getLogger(Whitelist.class);
    
    private Collection<String> requiredEntries = new HashSet<String>();
    
    private Collection<WhitelistEntry> whitelist = 
        new TreeSet<WhitelistEntry>();
    
    {
        // these domains host required services and can't be removed
        addDefaultEntry("getlantern.org", true);
        addDefaultEntry("google.com", true);
        addDefaultEntry("exceptional.io", true);

        // optional
        addDefaultEntry("avaaz.org", false);
        addDefaultEntry("bittorrent.com", false);
        addDefaultEntry("balatarin.com", false);
        addDefaultEntry("facebook.com", false);
        addDefaultEntry("flickr.com", false);
        addDefaultEntry("hrw.org", false); // Human Rights Watch
        addDefaultEntry("ifconfig.me", false);
        addDefaultEntry("linkedin.com", false);
        addDefaultEntry("littleshoot.org", false);
        addDefaultEntry("livejournal.com", false);
        addDefaultEntry("myspace.com", false);
        addDefaultEntry("orkut.com", false);
        addDefaultEntry("paypal.com", false);
        addDefaultEntry("reddit.com", false);
        addDefaultEntry("stumbleupon.com", false);
        addDefaultEntry("torproject.org", false);
        addDefaultEntry("tumblr.com", false);
        addDefaultEntry("twitter.com", false);
        addDefaultEntry("whatismyip.com", false);
        addDefaultEntry("wikileaks.org", false);
        addDefaultEntry("wordpress.org", false);
        addDefaultEntry("wordpress.com", false);
        addDefaultEntry("youtube.com", false);
    }
    
    public boolean isWhitelisted(final String uri,
        final Collection<WhitelistEntry> wl) {
        final String toMatch = toBaseUri(uri);
        return wl.contains(new WhitelistEntry(toMatch));
    }
    
    /**
     * Decides whether or not the specified full URI matches domains for our
     * whitelist.
     * 
     * @return <code>true</code> if the specified domain matches domains for
     * our whitelist, otherwise <code>false</code>.
     */
    public boolean isWhitelisted(final String uri) {
        return isWhitelisted(uri, whitelist);
    }
    
    /**
     * Decides whether or not the specified HttpRequest is for a domain on
     * our whitelist. Note this also checks the Referer header.
     * 
     * @return <code>true</code> if the specified domain matches domains for
     * our whitelist, otherwise <code>false</code>.
     */
    public boolean isWhitelisted(final HttpRequest request) {
        log.debug("Checking whitelist for request");
        final String uri = request.getUri();
        log.debug("URI is: {}", uri);

        final String referer = request.getHeader("referer");
        
        final String uriToCheck;
        log.debug("Referer: "+referer);
        if (!StringUtils.isBlank(referer)) {
            uriToCheck = referer;
        } else {
            uriToCheck = uri;
        }

        return isWhitelisted(uriToCheck);
    }
    
    private void addDefaultEntry(final String entry, final boolean required) {
        whitelist.add(new WhitelistEntry(entry, required, true));
        if (required) {
            this.requiredEntries.add(entry);
        }
    }
    
    public void addEntry(final String entry) {
        whitelist.add(new WhitelistEntry(entry));
    }

    public void removeEntry(final String entry) {
        if (!this.requiredEntries.contains(entry)) {
            whitelist.remove(new WhitelistEntry(entry));
        }
    }
    
    public Collection<WhitelistEntry> getEntries() {
        return whitelist;
    }
    
    public void setEntries(final Collection<WhitelistEntry> entries) {
        synchronized (whitelist) {
            this.whitelist = entries; 
        }
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
        log.debug("Matching against: {}", toMatch);
        return toMatch;
    }
}
