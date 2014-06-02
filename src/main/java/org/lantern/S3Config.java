package org.lantern;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
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
        List<FallbackProxy> allFallbacks = new ArrayList<FallbackProxy>(fallbacks);
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
        // Make this higher priority than other fallbacks
        flashlightProxy.setPriority(-1);
        return flashlightProxy;
    }
    
    public static Properties flashlightProps() {
        Properties props = new Properties();
        props.setProperty("type", "flashlight");
        props.setProperty(Flashlight.SERVER_KEY, "getiantem.org");
        props.setProperty(Flashlight.MASQUERADE_KEY, "cdnjs.com");
        props.setProperty(Flashlight.ROOT_CA_KEY, GLOBALSIGN_CA_CERT);
        return props;
    }
    
    // This cert is valid for cdnjs.com and may be valid for other CloudFlare
    // sites.
    private static final String GLOBALSIGN_CA_CERT = "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n";
}
