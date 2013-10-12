package org.lantern.network;

import static org.junit.Assert.*;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.nio.charset.Charset;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.util.HashSet;
import java.util.Set;

import org.junit.Test;

public class NetworkTrackerTest {
    @Test
    public void testTrust() throws Exception {
        final CertificateFactory cf = CertificateFactory.getInstance("X.509");
        final InputStream bis =
                new ByteArrayInputStream(VERISIGN_CERT.getBytes(Charset
                        .forName("UTF-8")));
        final Certificate cert = cf.generateCertificate(bis);

        InetSocketAddress addressA = new InetSocketAddress("host1.com", 5000);
        InetSocketAddress addressB = new InetSocketAddress("host1.com", 5001);
        InetSocketAddress addressC = new InetSocketAddress("host2.com", 5000);
        InetSocketAddress addressD = new InetSocketAddress("127.0.0.1", 5000);

        InstanceId instanceAA = new InstanceId("UserA", "UserA-A");
        InstanceId instanceAB = new InstanceId("UserA", "UserB-B");

        InstanceInfo instanceInfoAA = new InstanceInfo(instanceAA, addressA, addressB);
        InstanceInfo instanceInfoAB = new InstanceInfo(instanceAB, addressC, addressD);

        InstanceInfoWithCert instanceInfoWithCertAA = new InstanceInfoWithCert(
                instanceInfoAA, cert);
        InstanceInfoWithCert instanceInfoWithCertAB = new InstanceInfoWithCert(
                instanceInfoAB, cert);

        NetworkTracker tracker = new NetworkTracker();
        final Set<InstanceInfoWithCert> trustedByListener = new HashSet<InstanceInfoWithCert>();
        tracker.addListener(new NetworkTrackerListener() {

            @Override
            public void instanceOnlineAndTrusted(InstanceInfoWithCert instance) {
                trustedByListener.add(instance);
            }

            @Override
            public void instanceOfflineOrUntrusted(InstanceInfoWithCert instance) {
                trustedByListener.remove(instance);
            }
        });

        tracker.certificateReceived(instanceAA, cert);
        tracker.userTrusted("UserA");
        tracker.instanceOnline(instanceAB, instanceInfoAA);
        Set<InstanceInfoWithCert> allTrusted = tracker
                .getTrustedOnlineInstances();
        assertEquals(0, allTrusted.size());
        assertEquals(0, trustedByListener.size());

        tracker.instanceOnline(instanceAA, instanceInfoAA);
        allTrusted = tracker.getTrustedOnlineInstances();
        assertTrue(allTrusted.contains(instanceInfoWithCertAA));
        assertTrue(trustedByListener.contains(instanceInfoWithCertAA));

        tracker.instanceOnline(instanceAB, instanceInfoAB);
        allTrusted = tracker.getTrustedOnlineInstances();
        assertTrue(allTrusted.contains(instanceInfoWithCertAA));
        assertFalse(allTrusted.contains(instanceInfoWithCertAB));
        assertTrue(trustedByListener.contains(instanceInfoWithCertAA));
        assertFalse(trustedByListener.contains(instanceInfoWithCertAB));

        tracker.certificateReceived(instanceAB, cert);
        allTrusted = tracker.getTrustedOnlineInstances();
        assertTrue(allTrusted.contains(instanceInfoWithCertAA));
        assertTrue(allTrusted.contains(instanceInfoWithCertAB));
        assertTrue(trustedByListener.contains(instanceInfoWithCertAA));
        assertTrue(trustedByListener.contains(instanceInfoWithCertAB));

        tracker.instanceOffline(instanceAA);
        allTrusted = tracker.getTrustedOnlineInstances();
        assertFalse(allTrusted.contains(instanceInfoWithCertAA));
        assertTrue(allTrusted.contains(instanceInfoWithCertAB));
        assertFalse(trustedByListener.contains(instanceInfoWithCertAA));
        assertTrue(trustedByListener.contains(instanceInfoWithCertAB));

        tracker.userUntrusted("UserA");
        allTrusted = tracker.getTrustedOnlineInstances();
        assertEquals(0, allTrusted.size());
        assertEquals(0, trustedByListener.size());
    }

    // @formatter:off
    private static final String VERISIGN_CERT =
            "-----BEGIN CERTIFICATE-----\n"+
            "MIIE+DCCA+CgAwIBAgIQeo+SIwIaV15+swESSrlhUDANBgkqhkiG9w0BAQUFADCB\n"+
            "tTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\n"+
            "ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug\n"+
            "YXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykwOTEvMC0GA1UEAxMm\n"+
            "VmVyaVNpZ24gQ2xhc3MgMyBTZWN1cmUgU2VydmVyIENBIC0gRzIwHhcNMTAxMDA4\n"+
            "MDAwMDAwWhcNMTMxMDA3MjM1OTU5WjBpMQswCQYDVQQGEwJVUzETMBEGA1UECBMK\n"+
            "V2FzaGluZ3RvbjEQMA4GA1UEBxQHU2VhdHRsZTEYMBYGA1UEChQPQW1hem9uLmNv\n"+
            "bSBJbmMuMRkwFwYDVQQDFBBzMy5hbWF6b25hd3MuY29tMIGfMA0GCSqGSIb3DQEB\n"+
            "AQUAA4GNADCBiQKBgQDJccYKRvRt1Dq99i1G21g6UVMTm0ePye9sw2FtTYsOtAcx\n"+
            "2MEMO12W89ryqxjrJfW0Z8bCqw3HUv9cRczjxO+l5de6lnaMZUZNWGhA/Z0ajjzV\n"+
            "P59JKJu4I4zJf74N85hG99HB2t2oCw0cSJVoVQupZP0OUYoYLbxvO/v5UO0H5wID\n"+
            "AQABo4IB0TCCAc0wCQYDVR0TBAIwADALBgNVHQ8EBAMCBaAwRQYDVR0fBD4wPDA6\n"+
            "oDigNoY0aHR0cDovL1NWUlNlY3VyZS1HMi1jcmwudmVyaXNpZ24uY29tL1NWUlNl\n"+
            "Y3VyZUcyLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCowKAYIKwYBBQUH\n"+
            "AgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwHQYDVR0lBBYwFAYIKwYB\n"+
            "BQUHAwEGCCsGAQUFBwMCMB8GA1UdIwQYMBaAFKXvCxHOwEEDo0plkEiyHOBXLX1H\n"+
            "MHYGCCsGAQUFBwEBBGowaDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AudmVyaXNp\n"+
            "Z24uY29tMEAGCCsGAQUFBzAChjRodHRwOi8vU1ZSU2VjdXJlLUcyLWFpYS52ZXJp\n"+
            "c2lnbi5jb20vU1ZSU2VjdXJlRzIuY2VyMG4GCCsGAQUFBwEMBGIwYKFeoFwwWjBY\n"+
            "MFYWCWltYWdlL2dpZjAhMB8wBwYFKw4DAhoEFEtruSiWBgy70FI4mymsSweLIQUY\n"+
            "MCYWJGh0dHA6Ly9sb2dvLnZlcmlzaWduLmNvbS92c2xvZ28xLmdpZjANBgkqhkiG\n"+
            "9w0BAQUFAAOCAQEAer6KWnbs08+ZIAtj0eI9wq85KLj/NKuw9EZDgPDfO5vwfP7D\n"+
            "TKEhq8SDhTcRI+zr5FH28ev6ifio1ixFujbnTNDBryPfbzkIZvE7gahmzOYyZEOo\n"+
            "SaD4JDHqRQkVNZQMy3107tB7g/seSAEkQo6o5BVuKKEobGR8z4YFXAdq4Mg9ZoC1\n"+
            "WTBoIvQUMoM/ckIf9wRmiPgPSyTpMqFPE0pkTyJGfICrvcJbYN1XVqgHHZY5lbOw\n"+
            "JFoEknD6Zo6EMze/VVMewpseiHUT4DvBn/gtXMhEc/87QQ5ml9u+r+9QT+UjdI5w\n"+
            "W4wWQZ5AWPUZmZ4Dl8XgUPtCeArv8R+9zQVMHQ==\n"+
            "-----END CERTIFICATE-----";
    // @formatter:on
}
