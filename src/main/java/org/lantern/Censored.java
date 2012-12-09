package org.lantern;

import java.io.IOException;
import java.util.Collection;

/**
 * Interface for classes that keep track of censored countries.
 */
public interface Censored {

    boolean isCensored(String string) throws IOException;

    boolean isExportRestricted(String string) throws IOException;

    boolean isCensored();

    Collection<String> getCensored();

    boolean isCensored(Country country);

    String countryCode() throws IOException;

    Country country() throws IOException;

    boolean isCountryCodeCensored(String cc);

}
