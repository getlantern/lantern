package org.lantern;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Enumeration;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.TrustManagerFactory;

import org.lantern.event.Events;
import org.lantern.event.PeerCertEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Charsets;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class manages the local trust store of external entities we trust
 * for creating SSL connections. This includes both hard coded certificates
 * for a small number of services we use as well as dynamically added
 * certificates for peers. Peer certificates must be discovered and added
 * through a trusted channel such as one of the hard coded trusted authorities
 * (aka Google Talk with its equifax certificate as of this writing).
 */
@Singleton
public class LanternTrustStore {

    private final static Logger log = 
        LoggerFactory.getLogger(LanternTrustStore.class);
    
    private final AtomicReference<SSLContext> sslContextRef = 
            new AtomicReference<SSLContext>();
    private final LanternKeyStoreManager ksm;

    private final KeyStore trustStore;

    private TrustManagerFactory tmf;
    
    @Inject
    public LanternTrustStore(final LanternKeyStoreManager ksm) {
        this.ksm = ksm;
        this.trustStore = blankTrustStore();
        this.tmf = initTrustManagerFactory();
    }

    /**
     * Every time the trust store changes, we need to recreate particularly
     * our SSL context because we now trust different servers. We reload only
     * on trust store changes as an optimization to avoid loading the whole
     * SSL context from scratch for each new outgoing socket.
     */
    private void onTrustStoreChanged() {
        this.tmf = initTrustManagerFactory();
        this.sslContextRef.set(provideSslContext());
    }

    private TrustManagerFactory initTrustManagerFactory() {
        try {
            final TrustManagerFactory trustManagerFactory = 
                    TrustManagerFactory.getInstance(
                    TrustManagerFactory.getDefaultAlgorithm());
            
            // We create the trust manager factory with the latest trust store.
            trustManagerFactory.init(this.trustStore);
            return trustManagerFactory;
        } catch (final NoSuchAlgorithmException e) {
            log.error("Could not load algorithm?", e);
            throw new Error("Could not load algorithm", e);
        } catch (final KeyStoreException e) {
            log.error("Could not load keystore?", e);
            throw new Error("Could not load keystore for tmf", e);
        }
    }

    private KeyStore blankTrustStore() {
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(null, null);
            
            final CertificateFactory cf = CertificateFactory.getInstance("X.509");
            addCert(ks, cf, "littleproxy", LITTLEPROXY);
            addCert(ks, cf, "digicerthighassurancerootca", DIGICERT);
            addCert(ks, cf, "equifaxsecureca", EQUIFAX);
            addCert(ks, cf, "equifaxsecureca2", EQUIFAX2);
            return ks;
        } catch (final KeyStoreException e) {
            log.error("Could not load keystore?", e);
            throw new Error("Could not load blank trust store", e);
        } catch (final NoSuchAlgorithmException e) {
            log.error("No such algo?", e);
            throw new Error("Could not load blank trust store", e);
        } catch (final CertificateException e) {
            log.error("Bad cert?", e);
            throw new Error("Could not load blank trust store", e);
        } catch (final IOException e) {
            log.error("Could not load?", e);
            throw new Error("Could not load blank trust store", e);
        } 
    }

    private void addCert(final KeyStore ks, final CertificateFactory cf,
        final String alias, final String pemCert) 
                throws CertificateException, KeyStoreException {
        final InputStream bis = 
            new ByteArrayInputStream(pemCert.getBytes(Charsets.UTF_8));
        final Certificate cert = cf.generateCertificate(bis);
        ks.setCertificateEntry(alias, cert);
    }

    public void addCert(String pemCert) {
        try {
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            InputStream bis
                = new ByteArrayInputStream(pemCert.getBytes(Charsets.UTF_8));
            X509Certificate cert
                = (X509Certificate)cf.generateCertificate(bis);
            String alias = getCertAlias(cert);
            this.trustStore.setCertificateEntry(alias, cert);
            onTrustStoreChanged();
        } catch (CertificateException e) {
            log.error("Couldn't create certificate", e);
        } catch (KeyStoreException e) {
            log.error("Could not load cert into keystore", e);
        }
    }

    public void addCert(final String alias, final String pemCert) 
                throws CertificateException, KeyStoreException {
        final CertificateFactory cf = CertificateFactory.getInstance("X.509");
        addCert(this.trustStore, cf, alias, pemCert);
        onTrustStoreChanged();
    }

    public void addCert(URI jid, Certificate cert) {
        log.debug("Adding cert for {} to trust store", jid);
        Events.asyncEventBus().post(new PeerCertEvent(jid, cert));
        try {
            this.trustStore.setCertificateEntry(jid.toASCIIString(), cert);
        } catch (KeyStoreException e) {
            log.error("Could not load cert into keystore?", e);
        } 
        onTrustStoreChanged();
    }
    
    /**
     * Accessor for the SSL context. This is regenerated whenever
     * we receive new certificates.
     * 
     * @return The SSL context.
     */
    public synchronized SSLContext getSslContext() {
        if (this.sslContextRef.get() == null) {
            this.sslContextRef.set(provideSslContext());
        }
        final SSLContext context = sslContextRef.get();
        log.debug("Returning context: {}", context);
        return context;
    }
    
    /**
     * Return an new/unused {@link SSLEngine} reflecting our {@link SSLContext}.
     * For performance, these are created eagerly ahead of time.
     */
    public SSLEngine newSSLEngine() {
        return getSslContext().createSSLEngine();
    }

    private SSLContext provideSslContext() {
        try {
            final SSLContext context = SSLContext.getInstance("TLS");
            
            // Create the context with the latest trust manager factory.
            context.init(this.ksm.getKeyManagerFactory().getKeyManagers(), 
                this.tmf.getTrustManagers(), null);
            return context;
        } catch (final Exception e) {
            log.error("Failed to initialize the client-side SSLContext", e);
            throw new Error(
                    "Failed to initialize the client-side SSLContext", e);
        }
    }
    
    public void deleteCert(final String alias) {
        try {
            this.trustStore.deleteEntry(alias);
            onTrustStoreChanged();
        } catch (final KeyStoreException e) {
            log.debug("Error removing entry -- doesn't exist?", e);
        }
    }

    /**
     * Checks if the trust store contains exactly this certificate. This 
     * doesn't worry about certificate chaining or anything like that -- 
     * this trust store must instead contain the actual certificate.
     * 
     * @param cert The certificate to check.
     * @return <code>true</code> if the trust store contains the certificate,
     * otherwise <code>false</code>.
     */
    public boolean containsCertificate(final X509Certificate cert) {
        log.debug("Loading trust store...");
        
        // We could use KeyStore.getCertificateAlias here, but that will
        // iterate through everything, potentially causing issues when there
        // are a lot of certs.
        final String alias = getCertAlias(cert);
        log.debug("Looking for alias {}", alias);
        try {
            if (log.isDebugEnabled()) {
                log.debug("All aliases");
                Enumeration<String> aliases = this.trustStore.aliases();
                while (aliases.hasMoreElements()) {
                    log.debug(aliases.nextElement());
                }
            }
            final Certificate existingCert = this.trustStore.getCertificate(alias);
            log.trace("Existing certificate: {}", (existingCert));
            return existingCert != null && existingCert.equals(cert);
        } catch (final KeyStoreException e) {
            log.warn("Exception accessing keystore", e);
            return false;
        }
    }

    private String getCertAlias(X509Certificate cert) {
        return cert.getIssuerDN().getName().substring(3).toLowerCase();
    }

    private void listEntries(final KeyStore ks) {
        try {
            final Enumeration<String> aliases = ks.aliases();
            while (aliases.hasMoreElements()) {
                final String alias = aliases.nextElement();
                //System.err.println(alias+": "+ks.getCertificate(alias));
                System.err.println(alias);
                log.debug(alias);
            }
        } catch (final KeyStoreException e) {
            log.warn("KeyStore error", e);
        }
    }
    
    public void listEntries() {
        listEntries(trustStore);
    }

    private static final String EQUIFAX =
            "-----BEGIN CERTIFICATE-----\n"
            + "MIIDIDCCAomgAwIBAgIENd70zzANBgkqhkiG9w0BAQUFADBOMQswCQYDVQQGEwJV\n"
            + "UzEQMA4GA1UEChMHRXF1aWZheDEtMCsGA1UECxMkRXF1aWZheCBTZWN1cmUgQ2Vy\n"
            + "dGlmaWNhdGUgQXV0aG9yaXR5MB4XDTk4MDgyMjE2NDE1MVoXDTE4MDgyMjE2NDE1\n"
            + "MVowTjELMAkGA1UEBhMCVVMxEDAOBgNVBAoTB0VxdWlmYXgxLTArBgNVBAsTJEVx\n"
            + "dWlmYXggU2VjdXJlIENlcnRpZmljYXRlIEF1dGhvcml0eTCBnzANBgkqhkiG9w0B\n"
            + "AQEFAAOBjQAwgYkCgYEAwV2xWGcIYu6gmi0fCG2RFGiYCh7+2gRvE4RiIcPRfM6f\n"
            + "BeC4AfBONOziipUEZKzxa1NfBbPLZ4C/QgKO/t0BCezhABRP/PvwDN1Dulsr4R+A\n"
            + "cJkVV5MW8Q+XarfCaCMczE1ZMKxRHjuvK9buY0V7xdlfUNLjUA86iOe/FP3gx7kC\n"
            + "AwEAAaOCAQkwggEFMHAGA1UdHwRpMGcwZaBjoGGkXzBdMQswCQYDVQQGEwJVUzEQ\n"
            + "MA4GA1UEChMHRXF1aWZheDEtMCsGA1UECxMkRXF1aWZheCBTZWN1cmUgQ2VydGlm\n"
            + "aWNhdGUgQXV0aG9yaXR5MQ0wCwYDVQQDEwRDUkwxMBoGA1UdEAQTMBGBDzIwMTgw\n"
            + "ODIyMTY0MTUxWjALBgNVHQ8EBAMCAQYwHwYDVR0jBBgwFoAUSOZo+SvSspXXR9gj\n"
            + "IBBPM5iQn9QwHQYDVR0OBBYEFEjmaPkr0rKV10fYIyAQTzOYkJ/UMAwGA1UdEwQF\n"
            + "MAMBAf8wGgYJKoZIhvZ9B0EABA0wCxsFVjMuMGMDAgbAMA0GCSqGSIb3DQEBBQUA\n"
            + "A4GBAFjOKer89961zgK5F7WF0bnj4JXMJTENAKaSbn+2kmOeUJXRmm/kEd5jhW6Y\n"
            + "7qj/WsjTVbJmcVfewCHrPSqnI0kBBIZCe/zuf6IWUrVnZ9NA2zsmWLIodz2uFHdh\n"
            + "1voqZiegDfqnc1zqcPGUIWVEX/r87yloqaKHee9570+sB3c4\n"
            + "-----END CERTIFICATE-----";
    
    private static final String EQUIFAX2 =
    //i:/C=US/O=Equifax/OU=Equifax Secure Certificate Authority
            "-----BEGIN CERTIFICATE-----\n"
            + "MIIDfTCCAuagAwIBAgIDErvmMA0GCSqGSIb3DQEBBQUAME4xCzAJBgNVBAYTAlVT\n"
            + "MRAwDgYDVQQKEwdFcXVpZmF4MS0wKwYDVQQLEyRFcXVpZmF4IFNlY3VyZSBDZXJ0\n"
            + "aWZpY2F0ZSBBdXRob3JpdHkwHhcNMDIwNTIxMDQwMDAwWhcNMTgwODIxMDQwMDAw\n"
            + "WjBCMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UE\n"
            + "AxMSR2VvVHJ1c3QgR2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB\n"
            + "CgKCAQEA2swYYzD99BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9m\n"
            + "OSm9BXiLnTjoBbdqfnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIu\n"
            + "T8rxh0PBFpVXLVDviS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6c\n"
            + "JmTM386DGXHKTubU1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmR\n"
            + "Cw7+OC7RHQWa9k0+bw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5asz\n"
            + "PeE4uwc2hGKceeoWMPRfwCvocWvk+QIDAQABo4HwMIHtMB8GA1UdIwQYMBaAFEjm\n"
            + "aPkr0rKV10fYIyAQTzOYkJ/UMB0GA1UdDgQWBBTAephojYn7qwVkDBF9qn1luMrM\n"
            + "TjAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjA6BgNVHR8EMzAxMC+g\n"
            + "LaArhilodHRwOi8vY3JsLmdlb3RydXN0LmNvbS9jcmxzL3NlY3VyZWNhLmNybDBO\n"
            + "BgNVHSAERzBFMEMGBFUdIAAwOzA5BggrBgEFBQcCARYtaHR0cHM6Ly93d3cuZ2Vv\n"
            + "dHJ1c3QuY29tL3Jlc291cmNlcy9yZXBvc2l0b3J5MA0GCSqGSIb3DQEBBQUAA4GB\n"
            + "AHbhEm5OSxYShjAGsoEIz/AIx8dxfmbuwu3UOx//8PDITtZDOLC5MH0Y0FWDomrL\n"
            + "NhGc6Ehmo21/uBPUR/6LWlxz/K7ZGzIZOKuXNBSqltLroxwUCEm2u+WR74M26x1W\n"
            + "b8ravHNjkOR/ez4iyz0H7V84dJzjA1BOoa+Y7mHyhD8S\n"
            + "-----END CERTIFICATE-----";
    
    private static final String DIGICERT =
            "-----BEGIN CERTIFICATE-----\n"
            + "MIIGWDCCBUCgAwIBAgIQCl8RTQNbF5EX0u/UA4w/OzANBgkqhkiG9w0BAQUFADBs\n"
            + "MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\n"
            + "d3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5j\n"
            + "ZSBFViBSb290IENBMB4XDTA4MDQwMjEyMDAwMFoXDTIyMDQwMzAwMDAwMFowZjEL\n"
            + "MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3\n"
            + "LmRpZ2ljZXJ0LmNvbTElMCMGA1UEAxMcRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2Ug\n"
            + "Q0EtMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9hCikQH17+NDdR\n"
            + "CPge+yLtYb4LDXBMUGMmdRW5QYiXtvCgFbsIYOBC6AUpEIc2iihlqO8xB3RtNpcv\n"
            + "KEZmBMcqeSZ6mdWOw21PoF6tvD2Rwll7XjZswFPPAAgyPhBkWBATaccM7pxCUQD5\n"
            + "BUTuJM56H+2MEb0SqPMV9Bx6MWkBG6fmXcCabH4JnudSREoQOiPkm7YDr6ictFuf\n"
            + "1EutkozOtREqqjcYjbTCuNhcBoz4/yO9NV7UfD5+gw6RlgWYw7If48hl66l7XaAs\n"
            + "zPw82W3tzPpLQ4zJ1LilYRyyQLYoEt+5+F/+07LJ7z20Hkt8HEyZNp496+ynaF4d\n"
            + "32duXvsCAwEAAaOCAvowggL2MA4GA1UdDwEB/wQEAwIBhjCCAcYGA1UdIASCAb0w\n"
            + "ggG5MIIBtQYLYIZIAYb9bAEDAAIwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3\n"
            + "LmRpZ2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUH\n"
            + "AgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQBy\n"
            + "AHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBj\n"
            + "AGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAg\n"
            + "AEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQ\n"
            + "AGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBt\n"
            + "AGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBj\n"
            + "AG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBl\n"
            + "AHIAZQBuAGMAZQAuMBIGA1UdEwEB/wQIMAYBAf8CAQAwNAYIKwYBBQUHAQEEKDAm\n"
            + "MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wgY8GA1UdHwSB\n"
            + "hzCBhDBAoD6gPIY6aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0SGln\n"
            + "aEFzc3VyYW5jZUVWUm9vdENBLmNybDBAoD6gPIY6aHR0cDovL2NybDQuZGlnaWNl\n"
            + "cnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUVWUm9vdENBLmNybDAfBgNVHSME\n"
            + "GDAWgBSxPsNpA/i/RwHUmCYaCALvY2QrwzAdBgNVHQ4EFgQUUOpzidsp+xCPnuUB\n"
            + "INTeeZlIg/cwDQYJKoZIhvcNAQEFBQADggEBAB7ipUiebNtTOA/vphoqrOIDQ+2a\n"
            + "vD6OdRvw/S4iWawTwGHi5/rpmc2HCXVUKL9GYNy+USyS8xuRfDEIcOI3ucFbqL2j\n"
            + "CwD7GhX9A61YasXHJJlIR0YxHpLvtF9ONMeQvzHB+LGEhtCcAarfilYGzjrpDq6X\n"
            + "dF3XcZpCdF/ejUN83ulV7WkAywXgemFhM9EZTfkI7qA5xSU1tyvED7Ld8aW3DiTE\n"
            + "JiiNeXf1L/BXunwH1OH8zVowV36GEEfdMR/X/KLCvzB8XSSq6PmuX2p0ws5rs0bY\n"
            + "Ib4p1I5eFdZCSucyb6Sxa1GDWL4/bcf72gMhy2oWGU4K8K2Eyl2Us1p292E=\n"
            + "-----END CERTIFICATE-----";
    
    private static final String LITTLEPROXY =
            "-----BEGIN CERTIFICATE-----\n"
            + "MIIEqjCCApKgAwIBAgIETSOp+zANBgkqhkiG9w0BAQUFADAWMRQwEgYDVQQDEwts\n"
            + "aXR0bGVwcm94eTAgFw0xMTAxMDQyMzE1MDdaGA8yMTEwMTIxMTIzMTUwN1owFjEU\n"
            + "MBIGA1UEAxMLbGl0dGxlcHJveHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK\n"
            + "AoICAQCm4Ulsi69ZqgeSf+aVDFlVMkMWzYKomTcDFCX9rpys+nKiLpKbzXKruBUM\n"
            + "Ud9BSG1I3eiJ9jJP77f5DpW0z2bptOHSRi0a9GOpx6I8AjKBvKH2CtV8cnGsopN8\n"
            + "JMMop6tZ7hVRo3M0BmGh9SgAQaX46nVIwcA3oUSLQKEqAsw8WVmbYJhwNWpPAl5M\n"
            + "0BT/ElEKG2LPaB0ha+8mFeT3haq4Jeuxeb5MfnpuEnLQ4FTre27f7bO3r/QaxVpu\n"
            + "UHF6MyMjoQCcjUO99Fo6a0poo6XX7ys9jnPEl44Pt36ygced2S3U4ZtchWWf634B\n"
            + "Wh5jmHtrcdOo94emzHGdah+XnTJI5BYUyNgNeI/8D3OyTlVWxUDU4f/9XqxVtc1F\n"
            + "KjMe33eT6kL2s5GWaT+1R9dJ4TCFizPQrWrwu2IDbyDj2sJGdSrjj+w2kHQ/V17q\n"
            + "AD2TmDlMmIvrqRc1lptBhcSpdTp5EoZEvgwTyRM7jpwDj5rAUXV8eu/93NcImJY2\n"
            + "QkGxAamB2vFWwxxYShKUqyG1zxyIF1cvWnAywgZuE4t5TGiZ9AIor5XkNDcaE0pj\n"
            + "6yJtblOFhSKiJgSUR49dl0D39fzy++gkkWmjgUuRTMglx0wAFPxFa/TGhfK0Ukze\n"
            + "WpJxoWHR06+EPN0kj/nagk5q4Ovz8EOZratTwToCEi9Doe5N8wIDAQABMA0GCSqG\n"
            + "SIb3DQEBBQUAA4ICAQBiLlzTzBfFsvtfz6ll8mU8jptS6A3YV7Zldon25I/xQlik\n"
            + "72hS25+s2U3mzcIz1kkdSYhyTa8B1JhXygnUYkJV+AShP5+tlcYXWq1YMx9GrKC2\n"
            + "SEOrsmt2tHLJS03oyCZfYcKdoJMRoTXnKe8WDs7M4iFSXGeaFn1SePbdjNMGHCVT\n"
            + "Cr58PhCxigXushNAVy5GZFh0gcFeMIYJIUqJADbw4IyicXpcUdQJHs7DkvXxquXZ\n"
            + "rNv2NKWlqQI2iwn2Aow8V0c7mud/kGdzLFM18NZVfZQsWWBWXP3CxUPGGrfaxiCH\n"
            + "aLo1i9KnD6yEw9x/0mcajy3VN4y8QdJpgPhGDQXMMvqDWIEouy05sES4V0GVTksQ\n"
            + "42SscqVWyT0HNRgmvOQHEc9Oh9mkCuspEzSA+LH1CGYc+dSTUTZUO+MmcfMDYpj4\n"
            + "NkLH/AgVwKPiFyD5MUYi7isLJnfpkmZcgJOL/FXtGmLeD8nt8eRPRS4YZMLDtd/9\n"
            + "FVo6KC1mlaiosLys7wUBuu15HdyJrkD+k4ZNrkx/oMlcLOgPdz2Qkue3Rqa9DRuX\n"
            + "jwwv90xVufuOJ5mYcQ2VA80x8YT+XTq194BGSqYAAU8Rq1/5fAMg5cwhg4BDjmY2\n"
            + "ok2U3fCl58xbiwp6owpamVoPblrq7Zl4ylyF33H6ewM+f5XA+L1iC5KWs9q8Kw==\n"
            + "-----END CERTIFICATE-----";


}
