package org.lantern;

import java.util.Collection;
import java.util.HashSet;
import java.util.TreeSet;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Keeps track of which domains are whitelisted.
 */
public class Whitelist {

    private final Logger log = LoggerFactory.getLogger(Whitelist.class);
    
    private final Collection<String> requiredEntries = new HashSet<String>();
    
    public static final String[] SITES = {
        // optional
        "query.yahooapis.com",
        "avaaz.org",
        "bittorrent.com",
        "bloglines.com",
        "blogspot.com",
        "bloomberg.com",
        "box.com",
        "box.net",
        "change.org",
        "dailymotion.com",
        "docstoc.com",
        "dropbox.com",
        "eff.org",
        "facebook.com",
        "flickr.com",
        "friendfeed.com",
        "freedomhouse.org",
        "hrw.org", // Human Rights Watch
        "ifconfig.me",
        "igfw.net",
        "linkedin.com",
        "littleshoot.org",
        "livejournal.com",
        "myspace.com",
        "nytimes.com",
        "orkut.com",
        "paypal.com",
        "plurk.com",
        "posterous.com",
        "reddit.com",
        "rsf.org",
        "scribd.com",
        "stumbleupon.com",
        "torproject.org",
        "tumblr.com",
        "twitter.com",
        "vimeo.com",
        "whatismyip.com",
        "wikileaks.org",
        "wordpress.org",
        "wordpress.com",
        "youtube.com",
        
        // Iran-focused sites
        "30mail.net",
        "advar-news.biz",
        "balatarin.com",
        "bbc.co.uk",
        "bia2.com",
        "enghelabe-eslami.com",
        "gooya.com",
        "irangreenvoice.com",
        "iranian.com",
        "mardomak.org",
        "radiofarda.com",
        "radiozamaneh.com",
        "Roozonline.com",
        "voanews.com",
        
        
        // China (with various sub-categories below)
        "appledaily.com.tw",
        "boxun.com",
        "fc2.com",
        "hk.nextmedia.com",
        "inmediahk.net",
        "pchome.com.tw",
        "blog.idv.tw",
        "pixnet.net",
        "roodo.com",
        "wretch.cc",

        // Forums
        "canadameet.me",
        "chinasmile.net",
        "discuss.com.hk",
        //"dolc.de",
        "oursteps.com.au",
        "qoos.com",
        "sgchinese.net",
        "student.tw",
        "twbbs.tw",
        "uwants.com",
        

        // Cloud Storage (often porn, heavy load, so ignored for now).
        //https://www.rapidshare.com
        //http://www.4shared.com
        //https://www.sugarsync.com

        // News and Political
        "881903.com",
        "aboluowang.com",
        "www.am730.com.hk",
        "boxun.com",
        "bullogger.com",
        "canyu.org",
        "chinadigitaltimes.net",
        "chinainperspective.com",
        "dw.de",
        "epochtimes.com",
        "etaiwannews.com",
        "hrichina.org", 
        "globalvoicesonline.org",
        "libertytimes.com.tw",
        "mingpao.com",
        "molihua.org",
        //Re-enable pending the fix to https://github.com/getlantern/laeproxy/issues/14
        "www.newcenturynews.com", 
        "nextmedia.com",
        "ntdtv.com",
        "rfa.org",
        "rfi.fr",
        "rthk.hk",
        "singtao.com",
        "taiwandaily.net",
        "on.cc",
        "yzzk.com",
    };
    
    private Collection<WhitelistEntry> defaultWhitelist = 
        new HashSet<WhitelistEntry>();
    
    private Collection<WhitelistEntry> whitelist = 
        new TreeSet<WhitelistEntry>();
    
    {
        reset();
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
        final String referer = request.getHeader(HttpHeaders.Names.REFERER);
        return isWhitelisted(referer) || isWhitelisted(uri);
    }
    
    private void addDefaultEntry(final String entry) {
        addDefaultEntry(entry, false);
    }
    
    private void addDefaultEntry(final String entry, final boolean required) {
        final WhitelistEntry we = new WhitelistEntry(entry, required, true);
        whitelist.add(we);
        defaultWhitelist.add(we);
        if (required) {
            this.requiredEntries.add(entry);
        }
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
        if (!this.requiredEntries.contains(normalized)) {
            log.debug("Removing whitelist entry: {}", normalized);
            whitelist.remove(new WhitelistEntry(normalized));
        }
    }
    
    public Collection<WhitelistEntry> getEntries() {
        synchronized (whitelist) {
            return new TreeSet<WhitelistEntry>(whitelist);
        }
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
                domainExtension = StringUtils.substringBefore(domainExtension, ":");
            }
            String domain = StringUtils.substringBeforeLast(base, ".");
            log.debug("Domain: {}", domain);
            final String[] majorTlds = {"com", "org", "net"};
            for (final String tld : majorTlds) {
                if (domain.endsWith("."+tld)) {
                    domain = StringUtils.substringBeforeLast(domain, "."+tld);
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
        defaultWhitelist.clear();
        requiredEntries.clear();
        addDefaultEntry("getlantern.org", true);
        addDefaultEntry("google.com", true);
        addDefaultEntry("exceptional.io", true);
        for (final String site : SITES) {
            addDefaultEntry(site);
        }
    }
}
