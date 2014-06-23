package org.lantern;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Properties;

import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.lantern.proxy.FallbackProxy;
import org.lantern.proxy.pt.Flashlight;
import org.lantern.proxy.pt.PtType;
import org.littleshoot.util.FiveTuple.Protocol;

@JsonIgnoreProperties(ignoreUnknown=true)
public class S3Config {

    public static final String DEFAULT_CONTROLLER_ID = "lanternctrl1-2";
    public static final String DEFAULT_MASQUERADE_HOST = "cdnjs.com";
    
    private String controller = DEFAULT_CONTROLLER_ID;
    private int minpoll = 5;
    private int maxpoll = 15;
    private Collection<FallbackProxy> fallbacks = Collections.emptyList();
    
    /**
     * Milliseconds to wait before retrying disconnected signaling connections.
     */
    private long signalingRetryTime = 6000;
    
    /**
     * Get stats every minute.
     */
    private int statsGetInterval = 60;
    
    /**
     * Wait a bit before first posting stats, to give the system a 
     * chance to initialize metadata.
     */
    private int statsPostInterval = 5 * 60;
    
    private String masqueradeHost = DEFAULT_MASQUERADE_HOST;
    
    public S3Config() {}

    public String getController() {
        return controller;
    }
    public int getMinpoll() {
        return minpoll;
    }
    public int getMaxpoll() {
        return maxpoll;
    }
    
    public Collection<FallbackProxy> getFallbacks() {
        List<FallbackProxy> allFallbacks = new ArrayList<FallbackProxy>(
                fallbacks);
        boolean hasFlashlight = false;
        for (FallbackProxy proxy : allFallbacks) {
            if (PtType.FLASHLIGHT == proxy.getPtType()) {
                hasFlashlight = true;
            }
        }
        if (!hasFlashlight) {
            // If the S3 configuration didn't include a flashlight, add a
            // default one.
            allFallbacks.add(defaultFlashlightProxy());
        }
        return allFallbacks;
    }

    public void setController(String controller) {
        this.controller = controller;
    }

    public void setMinpoll(int minpoll) {
        this.minpoll = minpoll;
    }

    public void setMaxpoll(int maxpoll) {
        this.maxpoll = maxpoll;
    }

    public void setFallbacks(Collection<FallbackProxy> fallbacks) {
        this.fallbacks = fallbacks;
    }

    public int getStatsGetInterval() {
        return statsGetInterval;
    }

    public void setStatsGetInterval(int statsGetInterval) {
        this.statsGetInterval = statsGetInterval;
    }

    public int getStatsPostInterval() {
        return statsPostInterval;
    }

    public void setStatsPostInterval(int statsPostInterval) {
        this.statsPostInterval = statsPostInterval;
    }

    public long getSignalingRetryTime() {
        return signalingRetryTime;
    }

    public void setSignalingRetryTime(long signalingRetryTime) {
        this.signalingRetryTime = signalingRetryTime;
    }
    
    public String getMasqueradeHost() {
        return masqueradeHost;
    }
    
    public void setMasqueradeHost(String masqueradeHost) {
        this.masqueradeHost = masqueradeHost;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((controller == null) ? 0 : controller.hashCode());
        result = prime * result
                + ((fallbacks == null) ? 0 : fallbacks.hashCode());
        result = prime * result + maxpoll;
        result = prime * result + minpoll;
        result = prime * result
                + (int) (signalingRetryTime ^ (signalingRetryTime >>> 32));
        result = prime * result + statsGetInterval;
        result = prime * result + statsPostInterval;
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        S3Config other = (S3Config) obj;
        if (controller == null) {
            if (other.controller != null)
                return false;
        } else if (!controller.equals(other.controller))
            return false;
        if (fallbacks == null) {
            if (other.fallbacks != null)
                return false;
        } else if (!fallbacks.equals(other.fallbacks))
            return false;
        if (maxpoll != other.maxpoll)
            return false;
        if (minpoll != other.minpoll)
            return false;
        if (signalingRetryTime != other.signalingRetryTime)
            return false;
        if (statsGetInterval != other.statsGetInterval)
            return false;
        if (statsPostInterval != other.statsPostInterval)
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "S3Config [controller=" + controller + ", minpoll=" + minpoll
                + ", maxpoll=" + maxpoll + ", fallbacks=" + fallbacks
                + ", signalingRetryTime=" + signalingRetryTime
                + ", statsGetInterval=" + statsGetInterval
                + ", statsPostInterval=" + statsPostInterval + "]";
    }

 // Hard-coded flashlight proxy.  This could eventually be replaced by a
    // dynamic value fetched from S3.
    private static FallbackProxy defaultFlashlightProxy() {
        FallbackProxy flashlightProxy = new FallbackProxy();
        Properties ptProps = flashlightProps();
        flashlightProxy.setPt(ptProps);
        flashlightProxy.setIp(ptProps.getProperty(Flashlight.MASQUERADE_KEY));
        flashlightProxy.setPort(443);
        flashlightProxy.setProtocol(Protocol.TCP);
        // Make this lower priority than other fallbacks
        flashlightProxy.setPriority(1);
        return flashlightProxy;
    }
    
    public static Properties flashlightProps() {
        Properties props = new Properties();
        props.setProperty("type", "flashlight");
        props.setProperty(Flashlight.SERVER_KEY, "default.getiantem.org");
        props.setProperty(Flashlight.MASQUERADE_KEY, FASTLY_MASQUERADE_AS);
        props.setProperty(Flashlight.ROOT_CA_KEY, FASTLY_DIGICERT_HIGH_ASSURANCE_CA_3);
        return props;
    }
    
    private static final String CLOUDFLARE_MASQUERADE_AS = "cdnjs.com";
    
    private static final String FASTLY_MASQUERADE_AS = "assets-cdn.github.com";
    
    // This cert is valid for cdnjs.com and may be valid for other CloudFlare
    // sites.
    private static final String CLOUDFLARE_GLOBALSIGN_CA_CERT = "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n";
    
    // This cert is valid for assets-cdn.github.com and may be valid for other
    // Fastly sites.
    private static final String FASTLY_DIGICERT_HIGH_ASSURANCE_CA_3 = "-----BEGIN CERTIFICATE-----\nMIIGWDCCBUCgAwIBAgIQCl8RTQNbF5EX0u/UA4w/OzANBgkqhkiG9w0BAQUFADBs\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5j\nZSBFViBSb290IENBMB4XDTA4MDQwMjEyMDAwMFoXDTIyMDQwMzAwMDAwMFowZjEL\nMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3\nLmRpZ2ljZXJ0LmNvbTElMCMGA1UEAxMcRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2Ug\nQ0EtMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9hCikQH17+NDdR\nCPge+yLtYb4LDXBMUGMmdRW5QYiXtvCgFbsIYOBC6AUpEIc2iihlqO8xB3RtNpcv\nKEZmBMcqeSZ6mdWOw21PoF6tvD2Rwll7XjZswFPPAAgyPhBkWBATaccM7pxCUQD5\nBUTuJM56H+2MEb0SqPMV9Bx6MWkBG6fmXcCabH4JnudSREoQOiPkm7YDr6ictFuf\n1EutkozOtREqqjcYjbTCuNhcBoz4/yO9NV7UfD5+gw6RlgWYw7If48hl66l7XaAs\nzPw82W3tzPpLQ4zJ1LilYRyyQLYoEt+5+F/+07LJ7z20Hkt8HEyZNp496+ynaF4d\n32duXvsCAwEAAaOCAvowggL2MA4GA1UdDwEB/wQEAwIBhjCCAcYGA1UdIASCAb0w\nggG5MIIBtQYLYIZIAYb9bAEDAAIwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3\nLmRpZ2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUH\nAgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQBy\nAHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBj\nAGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAg\nAEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQ\nAGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBt\nAGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBj\nAG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBl\nAHIAZQBuAGMAZQAuMBIGA1UdEwEB/wQIMAYBAf8CAQAwNAYIKwYBBQUHAQEEKDAm\nMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wgY8GA1UdHwSB\nhzCBhDBAoD6gPIY6aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0SGln\naEFzc3VyYW5jZUVWUm9vdENBLmNybDBAoD6gPIY6aHR0cDovL2NybDQuZGlnaWNl\ncnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUVWUm9vdENBLmNybDAfBgNVHSME\nGDAWgBSxPsNpA/i/RwHUmCYaCALvY2QrwzAdBgNVHQ4EFgQUUOpzidsp+xCPnuUB\nINTeeZlIg/cwDQYJKoZIhvcNAQEFBQADggEBAB7ipUiebNtTOA/vphoqrOIDQ+2a\nvD6OdRvw/S4iWawTwGHi5/rpmc2HCXVUKL9GYNy+USyS8xuRfDEIcOI3ucFbqL2j\nCwD7GhX9A61YasXHJJlIR0YxHpLvtF9ONMeQvzHB+LGEhtCcAarfilYGzjrpDq6X\ndF3XcZpCdF/ejUN83ulV7WkAywXgemFhM9EZTfkI7qA5xSU1tyvED7Ld8aW3DiTE\nJiiNeXf1L/BXunwH1OH8zVowV36GEEfdMR/X/KLCvzB8XSSq6PmuX2p0ws5rs0bY\nIb4p1I5eFdZCSucyb6Sxa1GDWL4/bcf72gMhy2oWGU4K8K2Eyl2Us1p292E=\n-----END CERTIFICATE-----";
}
