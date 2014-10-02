package org.lantern;

import static org.junit.Assert.*;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLSocket;

import org.junit.Test;

public class CertPinningSSLContextSourceTest {
    private CertPinningSSLContextSource source = new CertPinningSSLContextSource(
            "google", GOOGLE_CERT);

    @Test
    public void testSuccess() throws Exception {
        SSLSocket socket = (SSLSocket) source.getContext("www.google.com")
                .getSocketFactory()
                .createSocket();
        socket.connect(new InetSocketAddress("www.google.com", 443));
        socket.startHandshake();
    }

    @Test
    public void testFailure() throws Exception {
        SSLSocket socket = (SSLSocket) source.getContext("www.google.com")
                .getSocketFactory()
                .createSocket();
        socket.connect(new InetSocketAddress("www.facebook.com", 443));
        try {
            socket.startHandshake();
            fail("Facebook shouldn't have been allowed with Google cert");
        } catch (Exception e) {
            // this is okay
        }
    }

    private static final String GOOGLE_CERT = "-----BEGIN CERTIFICATE-----\n"
            + "MIIEdjCCA16gAwIBAgIIMODC21opqnowDQYJKoZIhvcNAQEFBQAwSTELMAkGA1UE\n"
            + "BhMCVVMxEzARBgNVBAoTCkdvb2dsZSBJbmMxJTAjBgNVBAMTHEdvb2dsZSBJbnRl\n"
            + "cm5ldCBBdXRob3JpdHkgRzIwHhcNMTQwOTEwMTM0OTM2WhcNMTQxMjA5MDAwMDAw\n"
            + "WjBoMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwN\n"
            + "TW91bnRhaW4gVmlldzETMBEGA1UECgwKR29vZ2xlIEluYzEXMBUGA1UEAwwOd3d3\n"
            + "Lmdvb2dsZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCQB+vv\n"
            + "sJ/b+V77nEzwXIfBZvkz1sFFeZZhrisfngTOJ0AvvRs1YGBYgG1LXHOsC/5YDRlb\n"
            + "Vni5saLQAYaER22WqYL9Ar5SlVZeTq5Q6aBid7ydFdQy7YPhJLAUtZK+pIezzmra\n"
            + "wxe+BnL4YWwotUsGGcKI3Q8qbnQPlUy9kw8XRcfex1H3+FvLasuarGrKYNqG5r53\n"
            + "3Hl+MIOIS0IfefANKK2th3xvvrCDC9D/4LjZWgNCg0KaM1PE7yx4vKKm1le7UbIs\n"
            + "walfxPxhdeCR1DtX70YsKWTwTAShrEilv3z8EBS6HNbhaG1i4qG7xbncQolE0PkX\n"
            + "QbDK8dKw1O/m5ulBAgMBAAGjggFBMIIBPTAdBgNVHSUEFjAUBggrBgEFBQcDAQYI\n"
            + "KwYBBQUHAwIwGQYDVR0RBBIwEIIOd3d3Lmdvb2dsZS5jb20waAYIKwYBBQUHAQEE\n"
            + "XDBaMCsGCCsGAQUFBzAChh9odHRwOi8vcGtpLmdvb2dsZS5jb20vR0lBRzIuY3J0\n"
            + "MCsGCCsGAQUFBzABhh9odHRwOi8vY2xpZW50czEuZ29vZ2xlLmNvbS9vY3NwMB0G\n"
            + "A1UdDgQWBBQ3BfxMJBnob5lrgYqhZG9b/cnqpDAMBgNVHRMBAf8EAjAAMB8GA1Ud\n"
            + "IwQYMBaAFErdBhYbvPZotXb1gba7Yhq6WoEvMBcGA1UdIAQQMA4wDAYKKwYBBAHW\n"
            + "eQIFATAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vcGtpLmdvb2dsZS5jb20vR0lB\n"
            + "RzIuY3JsMA0GCSqGSIb3DQEBBQUAA4IBAQBb9zfUny3iAeNP7IZS2dvuNrTG4clT\n"
            + "+VyuDRf5UeYSRQjl4HMSdo+Fxf3iluZf7qE/5GEKbjCD9fSPfIcnu+vdLSLd+1ox\n"
            + "PjgZ+EiWwDr20Qc+qa+SwF3F9ZcsxBjFfbH8R9QzkDlj60ptvfzlqKWrjmRrhw9v\n"
            + "LDf0QL2q0Y4kWp9Ef2O7ONmitmdkCeaFubMU5gR8TfD558XRhShDC35T7nU0Y84Q\n"
            + "VsvNug3mVd/gQaj5+ppalzoTLXW+hqwSR7Q7RtCXkTHE31zxcH9usgyR8kkyZrMC\n"
            + "3BI7qzLDd56CLX3bRwWnOqgBBD16ihv0EG4+TBtJgyjZmWsj0Z8fD/7g\n"
            + "-----END CERTIFICATE-----";
}
