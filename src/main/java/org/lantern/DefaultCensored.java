package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.util.Collection;
import java.util.TreeSet;

import org.lantern.geoip.GeoIpLookupService;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.Sets;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class that keeps track of which countries are considered censored.
 */
@Singleton
public class DefaultCensored implements Censored {

    private static final Logger LOG = 
        LoggerFactory.getLogger(DefaultCensored.class);

    private static final Collection<String> CENSORED =
        new TreeSet<String>(Sets.newHashSet(
            // These are taken from ONI data -- 11/16/11 - any country containing
            // any type of censorship considered "substantial" or "pervasive".
            "AE", // United Arab Emirates
            "AM", // Armenia
            "BH", // Bahrain
            "CN", // China
            "CU", // Cuba
            "ET", // Ethiopia
            //"ID", // Indonesia
            "IR", // Iran
            "KP", // North Korea
            "KR", // South Korea
            "KW", // Kuwait
            "MM", // Myanmar
            "OM", // Oman
            //"PK", // Pakistan
            "PS", // Palestine
            "QA", // Qatar
            "SA", // Saudi Arabia
            "SD", // Sudan
            "SY", // Syria
            "TM", // Turkmenistan
            "UZ", // Uzbekistan
            "VN", // Vietnam
            "YE" // Yemen
        ));

    private final GeoIpLookupService lookupService;

    @Inject
    public DefaultCensored(final GeoIpLookupService lookupService) {
        this.lookupService = lookupService;
    }

    /**
     * This is just used for testing...
     */
    public DefaultCensored() {
        this(new GeoIpLookupService());
    }

    // These country codes have US export restrictions, and therefore cannot
    // access App Engine sites.
    private final Collection<String> EXPORT_RESTRICTED =
        Sets.newHashSet(
            "SY");

    @Override
    public boolean isCensored() {
        return isCensored(new PublicIpAddress().getPublicIpAddress());
    }
    
    @Override
    public boolean isCensored(final Country country) { 
        final String cc = country.getCode().trim();
        return CENSORED.contains(cc);
    }


    public boolean isExportRestricted() {
        return isExportRestricted(new PublicIpAddress().getPublicIpAddress());
    }
    
    public boolean isExportRestricted(final InetAddress address) { 
        return isMatch(address, EXPORT_RESTRICTED);
    }

    @Override
    public boolean isExportRestricted(final String address) 
        throws IOException {
        return isExportRestricted(InetAddress.getByName(address));
    }
    
    private boolean isCensored(final InetAddress address) {
        return isMatch(address, CENSORED);
    }
    private boolean isMatch(final InetAddress address, 
        final Collection<String> countries) { 
        if (address == null) {
            return true;
        }
        return countries.contains(countryCode(address));
    }
    
    private String countryCode(final InetAddress address) {
        return lookupService.getLocation(address).getCountry();
    }

    @Override
    public boolean isCountryCodeCensored(String cc) {
        return CENSORED.contains(cc);
    }
}
