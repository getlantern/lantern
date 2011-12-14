package org.lantern;

/**
 * Interface for classes handling the configuration API.
 */
public interface ConfigApi {

    String roster();
    
    String whitelist();

    String httpsEverywhere();

    String whitelist(String body);

    String addToWhitelist(String body);

    String removeFromWhitelist(String body);

    String addToTrusted(String body);

    String removeFromTrusted(String body);

    String config();

}
