package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.util.Collection;
import java.util.zip.GZIPInputStream;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.Sets;
import com.maxmind.geoip.Country;
import com.maxmind.geoip.LookupService;

public class CensoredUtils {

    private static final Logger LOG = 
        LoggerFactory.getLogger(CensoredUtils.class);

    /**
     * Censored country codes, in order of population.
     */
    private static final Collection<String> CENSORED =
        Sets.newHashSet(
            // Asia 
            "CN",
            "VN",
            "MM",
            //Mideast: 
            "IR", 
            "BH", 
            "YE", 
            "SA", 
            "SY",
            //Eurasia: 
            "UZ", 
            "TM",
            //Africa: 
            "ET", 
            "ER",
            // LAC: 
            "CU");

    // These country codes have US export restrictions, and therefore cannot
    // access App Engine sites.
    private static final Collection<String> EXPORT_RESTRICTED =
        Sets.newHashSet(
            "SY");
    
    private static final File UNZIPPED = 
        new File(LanternUtils.dataDir(), "GeoIP.dat");
    
    private static LookupService lookupService;

    private static String countryCode;

    static {
        if (!UNZIPPED.isFile())  {
            final File file = new File("GeoIP.dat.gz");
            GZIPInputStream is = null;
            OutputStream os = null;
            try {
                is = new GZIPInputStream(new FileInputStream(file));
                os = new FileOutputStream(UNZIPPED);
                IOUtils.copy(is, os);
            } catch (final IOException e) {
                LOG.error("Error expanding file?", e);
            } finally {
                IOUtils.closeQuietly(is);
                IOUtils.closeQuietly(os);
            }
        }
        try {
            lookupService = new LookupService(UNZIPPED, 
                    LookupService.GEOIP_MEMORY_CACHE);
        } catch (final IOException e) {
            LOG.error("Could not create LOOKUP service?");
            lookupService = null;
        }
    }
    
    public static String countryCode() {
        if (StringUtils.isNotBlank(countryCode)) {
            return countryCode;
        }
        
        countryCode = countryCode(new PublicIpAddress().getPublicIpAddress());
        return countryCode;
    }
    
    public static String countryCode(final InetAddress address) {
        final Country country = lookupService.getCountry(address);
        LOG.info("Country is: {}", country.getName());
        return country.getCode().trim();
    }
    
    public static boolean isCensored() {
        return isCensored(new PublicIpAddress().getPublicIpAddress());
    }
    
    public static boolean isCensored(final InetAddress address) {
        return isMatch(address, CENSORED);
    }

    public static boolean isCensored(final String address) throws IOException {
        return isCensored(InetAddress.getByName(address));
    }
    
    public static boolean isExportRestricted() {
        return isExportRestricted(new PublicIpAddress().getPublicIpAddress());
    }
    
    public static boolean isExportRestricted(final InetAddress address) { 
        return isMatch(address, EXPORT_RESTRICTED);
    }

    public static boolean isExportRestricted(final String address) 
        throws IOException {
        return isExportRestricted(InetAddress.getByName(address));
    }
    
    public static boolean isMatch(final InetAddress address, 
        final Collection<String> countries) { 
        final Country country = lookupService.getCountry(address);
        LOG.info("Country is: {}", country.getName());
        countryCode = country.getCode().trim();
        return countries.contains(countryCode);
    }
    

    public static boolean isForceCensored() {
        final boolean force = 
            LanternUtils.getBooleanProperty(LanternConstants.FORCE_CENSORED);
        LOG.info("Forcing proxy: "+force);
        return force;
    }

    public static void forceCensored() {
        LanternUtils.setBooleanProperty(LanternConstants.FORCE_CENSORED, true);
    }

    public static void unforceCensored() {
        LanternUtils.setBooleanProperty(LanternConstants.FORCE_CENSORED, false);
    }
}
