package org.lantern;

import java.util.Collection;

import org.jboss.netty.handler.codec.http.HttpRequest;

/**
 * Interface for controlling the list of whitelisted sites.
 */
public interface Whitelist {

    Collection<WhitelistEntry> getWhitelist();

    void removeEntry(String entry);

    void addEntry(String entry);

    boolean isWhitelisted(String site);

    String getAdditionsAsJson();

    String getRemovalsAsJson();

    boolean isWhitelisted(String string, Collection<WhitelistEntry> whitelist);

    void whitelistReported();

    void reset();

    Collection<WhitelistEntry> getRemovals();

    Collection<WhitelistEntry> getAdditions();

    boolean isWhitelisted(HttpRequest request);
}
