package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.util.Collection;
import java.util.TreeSet;

import org.apache.commons.lang.StringUtils;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.state.Location;
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

    private String countryCode;
    
    @Override
    public String countryCode() throws IOException {
        if (StringUtils.isNotBlank(countryCode)) {
            LOG.info("Returning cached country code: {}", countryCode);
            return countryCode;
        }
        
        LOG.info("Returning country code: {}", countryCode);
        countryCode = country().getCode().trim();
        return countryCode;
    }
    
    @Override
    public Country country() throws IOException {
        final InetAddress address = new PublicIpAddress().getPublicIpAddress();
        if (address == null) {
            // Just return an empty country instead of throwing null pointer.
            LOG.warn("Could not get public IP!!");
            return new Country("", "", true);
        }
        Location location = lookupService.getLocation(address);
        return Country.getCountryByCode(location.getCountry());
    }

    @Override
    public boolean isCensored() {
        return isCensored(new PublicIpAddress().getPublicIpAddress());
    }
    
    @Override
    public boolean isCensored(final Country country) { 
        final String cc = country.getCode().trim();
        return CENSORED.contains(cc);
    }

    @Override
    public Collection<String> getCensored() {
        return CENSORED;
    }
    
    @Override
    public boolean isCensored(final String address) throws IOException {
        return isCensored(InetAddress.getByName(address));
    }
    

    @Override
    public boolean isCountryCodeCensored(final String cc) {
        if (StringUtils.isBlank(cc)) {
            return false;
        }
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
}
