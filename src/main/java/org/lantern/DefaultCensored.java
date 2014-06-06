package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.util.Collection;
import java.util.TreeSet;

import org.lantern.annotation.Keep;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.util.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.Sets;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class that keeps track of which countries are considered censored.
 */
@Singleton
@Keep
public class DefaultCensored implements Censored {

    private static final Logger LOG = 
        LoggerFactory.getLogger(DefaultCensored.class);

    private static final Collection<String> CENSORED =
        new TreeSet<String>(Sets.newHashSet(
            // Last updated 2013-12-19 based on discussion in:
            // https://groups.google.com/forum/#!topic/lantern-devel/0dMPEVOLc68

            // "biggies":
            "CN", // China
            "VN", // Vietnam
            "IR", // Iran
            "CU", // Cuba

            // "all count":
            "SY", // Syria
            "SA", // Saudi Arabia
            "BH", // Bahrain
            "ET", // Ethiopia
            "ER", // Eritrea [1]
            "UZ", // Uzbekistan
            "TM", // Turkmenistan
            "PK", // Pakistan [1]
            "TR"  // Turkey


            // "some cybercensorship, but it’s either not much, nor not much
            // that people care a lot about, or haphazard -- at any rate, it
            // doesn’t tend to be bad enough to provoke the market for
            // circumvention tools to develop/exist":
//          "QA", // Qatar [2]
//          "SD", // Sudan [2]
//          "JO", // Jordan
//          "AE", // United Arab Emirates [2]
//          "RU", // Russia
//          "TH", // Thailand
//          "KH", // Cambodia
//          "TJ", // Tajikistan
//          "KZ", // Kazakhstan
//          "MA", // Morocco
//          "AF", // Afghanistan
//          "ID", // Indonesia
//          "IN", // India
//          "LK", // Sri Lanka
//          "KW"  // Kuwait [2]


            // "Myanmar has no cybercensorship (or, no more than the US
            // has—less, in fact). ONI’s data are waaaay out of date. (I was
            // the original source of MM’s data, from when I ran the first
            // rTurtle test here in 2005.)"
//          "MM", // Myanmar [2]


            // "BY censors one site which no one even knows about. BY takes
            // censorship flak because during “events” (elections,
            // demonstrations)—once or twice a year—it throttles Belarusians’
            // access to the ~7 major indy BY news sites for about three days."
//          "BY", // Belarus


            // "KP doesn’t have any publicly accessible internet at all. So
            // I wouldn’t include it in the “censoring” category. That I know
            // of (second-hand stories from friends who’ve been), the internet
            // available to expats in hotels isn’t censored."
//          "KP", // North Korea [2]


            // [1] not on our old list
            // [2] on our old list



            // on our old list, but not mentioned in the thread:
//          "AM", // Armenia
//          "KW", // Kuwait
//          "OM", // Oman
//          "PS", // Palestine
//          "YE"  // Yemen
//          "KR", // South Korea

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
    
    @Override
    public boolean isCensored(final InetAddress address) {
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
        return lookupService.getGeoData(address).getCountry().getIsoCode();
    }

    @Override
    public boolean isCountryCodeCensored(String cc) {
        return CENSORED.contains(cc);
    }
}
