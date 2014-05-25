package org.lantern;

import java.io.IOException;
import java.net.InetAddress;

import org.lantern.annotation.Keep;
/**
 * Interface for classes that keep track of censored countries.
 */
@Keep
public interface Censored {

    boolean isExportRestricted(String string) throws IOException;

    boolean isCensored();

    boolean isCensored(Country country);

    boolean isCountryCodeCensored(String cc);

    boolean isCensored(InetAddress address);

}
