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
        addDefaultEntry("avaaz.org");
        addDefaultEntry("bittorrent.com");
        addDefaultEntry("bloglines.com");
        addDefaultEntry("box.com");
        addDefaultEntry("box.net");
        addDefaultEntry("dropbox.com");
        addDefaultEntry("facebook.com");
        addDefaultEntry("flickr.com");
        addDefaultEntry("friendfeed.com");
        addDefaultEntry("hrw.org"); // Human Rights Watch
        addDefaultEntry("ifconfig.me");
        addDefaultEntry("linkedin.com");
        addDefaultEntry("littleshoot.org");
        addDefaultEntry("livejournal.com");
        addDefaultEntry("myspace.com");
        addDefaultEntry("orkut.com");
        addDefaultEntry("paypal.com");
        addDefaultEntry("plurk.com");
        addDefaultEntry("posterous.com");
        addDefaultEntry("reddit.com");
        addDefaultEntry("stumbleupon.com");
        addDefaultEntry("torproject.org");
        addDefaultEntry("tumblr.com");
        addDefaultEntry("twitter.com");
        addDefaultEntry("whatismyip.com");
        addDefaultEntry("wikileaks.org");
        addDefaultEntry("wordpress.org");
        addDefaultEntry("wordpress.com");
        addDefaultEntry("youtube.com");
        
        // Iran-focused sites
        addDefaultEntry("30mail.net");
        addDefaultEntry("advar-news.biz");
        addDefaultEntry("balatarin.com");
        addDefaultEntry("bbc.co.uk");
        addDefaultEntry("bia2.com");
        addDefaultEntry("enghelabe-eslami.com");
        addDefaultEntry("gooya.com");
        addDefaultEntry("irangreenvoice.com");
        addDefaultEntry("iranian.com");
        addDefaultEntry("mardomak.org");
        addDefaultEntry("radiofarda.com");
        addDefaultEntry("radiozamaneh.com");
        addDefaultEntry("Roozonline.com");
        addDefaultEntry("voanews.com");
        
        
        // China (with various sub-categories below)
        addDefaultEntry("pchome.com.tw");
        addDefaultEntry("wretch.cc");
        addDefaultEntry("pixnet.net");
        addDefaultEntry("roodo.com");
        addDefaultEntry("idv.tw");
        addDefaultEntry("fc2.com");

        // Forums
        addDefaultEntry("canadameet.me");
        addDefaultEntry("chinasmile.net");
        addDefaultEntry("discuss.com.hk");
        addDefaultEntry("dolc.de");
        addDefaultEntry("oursteps.com.au");
        addDefaultEntry("qoos.com");
        addDefaultEntry("sgchinese.net");
        addDefaultEntry("student.tw");
        addDefaultEntry("twbbs.tw");
        addDefaultEntry("uwants.com");
        

        // Cloud Storage (often porn, heavy load, so ignored for now).
        //https://www.rapidshare.com
        //http://www.4shared.com
        //https://www.sugarsync.com

        // News and Political
        addDefaultEntry("881903.com");
        addDefaultEntry("aboluowang.com");
        addDefaultEntry("am730.com.hk");
        addDefaultEntry("boxun.com");
        addDefaultEntry("bullogger.com");
        addDefaultEntry("canyu.org");
        addDefaultEntry("chinadigitaltimes.net");
        addDefaultEntry("chinainperspective.com");
        addDefaultEntry("dw.de");
        addDefaultEntry("epochtimes.com");
        addDefaultEntry("etaiwannews.com");
        addDefaultEntry("globalvoicesonline.org");
        addDefaultEntry("libertytimes.com.tw");
        addDefaultEntry("mingpao.com");
        addDefaultEntry("molihua.org");
        addDefaultEntry("newcenturynews.com");
        addDefaultEntry("nextmedia.com");
        addDefaultEntry("ntdtv.com");
        addDefaultEntry("rfa.org");
        addDefaultEntry("rfi.fr");
        addDefaultEntry("rthk.hk");
        addDefaultEntry("singtao.com");
        addDefaultEntry("taiwandaily.net");
        addDefaultEntry("the-sun.on.cc");
        addDefaultEntry("yzzk.com");
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
    
    private void addDefaultEntry(final String entry) {
        addDefaultEntry(entry, false);
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
}
