package org.lantern;

import java.io.IOException;
/**
 * Interface for classes that keep track of censored countries.
 */
public interface Censored {

    boolean isExportRestricted(String string) throws IOException;

    boolean isCensored();

    boolean isCensored(Country country);

    boolean isCountryCodeCensored(String cc);

}
