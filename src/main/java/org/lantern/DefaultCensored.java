package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.util.Collection;
import java.util.TreeSet;
import java.util.zip.GZIPInputStream;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.Sets;
import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.maxmind.geoip.LookupService;

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

    private final LookupService lookupService;
    
    @Inject
    public DefaultCensored(final LookupService lookupService) {
        this.lookupService = lookupService;
    }

    /**
     * This is just used for testing...
     */
    public DefaultCensored() {
        this(provideLookupService());
    }
    
    private static LookupService provideLookupService() {
        final File unzipped = 
                new File(LanternConstants.DATA_DIR, "GeoIP.dat");
        if (!unzipped.isFile())  {
            final File file = new File("GeoIP.dat.gz");
            GZIPInputStream is = null;
            OutputStream os = null;
            try {
                is = new GZIPInputStream(new FileInputStream(file));
                os = new FileOutputStream(unzipped);
                IOUtils.copy(is, os);
            } catch (final IOException e) {
                LOG.error("Error expanding file?", e);
            } finally {
                IOUtils.closeQuietly(is);
                IOUtils.closeQuietly(os);
            }
        }
        try {
            return new LookupService(unzipped, 
                    LookupService.GEOIP_MEMORY_CACHE);
        } catch (final IOException e) {
            LOG.error("Could not create LOOKUP service?");
        }
        return null;
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
        final com.maxmind.geoip.Country country = 
            lookupService.getCountry(address);
        return new Country(country.getCode(), country.getName(), 
            isCountryCodeCensored(country.getCode()));
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
        final com.maxmind.geoip.Country country = 
            lookupService.getCountry(address);
        LOG.info("Country is: {}", country.getName());
        return country.getCode().trim();
    }
}
