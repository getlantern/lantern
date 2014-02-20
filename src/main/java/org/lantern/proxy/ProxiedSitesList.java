package org.lantern.proxy;

import java.util.Arrays;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.regex.Pattern;

import org.lantern.util.SuffixMatcher;

/**
 * A list of Proxied Sites.
 */
public class ProxiedSitesList {
    private static final Pattern IPv4 = Pattern
            .compile("[0-9]{3}.[0-9]{3}.[0-9]{3}.[0-9]{3}");

    private final Queue<String> proxiedSites;
    private final SuffixMatcher suffixMatcher;

    public ProxiedSitesList() {
        this(new String[0]);
    }

    public ProxiedSitesList(String[] proxiedSites) {
        this.proxiedSites = new ConcurrentLinkedQueue<String>(
                Arrays.asList(proxiedSites));
        this.suffixMatcher = new SuffixMatcher(this.proxiedSites);
    }

    /**
     * Determine whether the given host is on the list using a suffix match.
     * 
     * @param host
     * @return
     */
    public boolean includes(String host) {
        boolean isIp = IPv4.matcher(host).matches();
        String longestMatchingSuffix =
                suffixMatcher.longestMatchingSuffix(host);
        if (isIp) {
            // For ip addresses, the whole ip has to be on the proxied sites
            // list
            return host.equals(longestMatchingSuffix);
        } else {
            // For domain names, as long as any part of the domain name has a
            // suffix match, that means it is proxied.
            return longestMatchingSuffix != null;
        }
    }
}
