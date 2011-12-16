package org.lantern;

import java.util.Map;

/**
 * Interface for classes handling the configuration API.
 */
public interface ConfigApi {

    String roster();
    
    String whitelist();

    String httpsEverywhere();

    String addToWhitelist(String body);

    String removeFromWhitelist(String body);

    String addToTrusted(String body);

    String removeFromTrusted(String body);

    Map<String, Object> config();

    String setConfig(Map<String, String> args);

    String configAsJson();

}
