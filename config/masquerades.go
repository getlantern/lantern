package config

import "github.com/getlantern/flashlight/client"

var defaultTrustedCAs = []*CA{ 
    &CA{
        CommonName: "GlobalSign Root CA",
        Cert:       "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n",
    }, 
    &CA{
        CommonName: "AddTrust External CA Root",
        Cert:       "-----BEGIN CERTIFICATE-----\nMIIENjCCAx6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBvMQswCQYDVQQGEwJTRTEU\nMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFs\nIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290\nMB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowbzELMAkGA1UEBhMCU0Ux\nFDASBgNVBAoTC0FkZFRydXN0IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5h\nbCBUVFAgTmV0d29yazEiMCAGA1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9v\ndDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALf3GjPm8gAELTngTlvt\nH7xsD821+iO2zt6bETOXpClMfZOfvUq8k+0DGuOPz+VtUFrWlymUWoCwSXrbLpX9\nuMq/NzgtHj6RQa1wVsfwTz/oMp50ysiQVOnGXw94nZpAPA6sYapeFI+eh6FqUNzX\nmk6vBbOmcZSccbNQYArHE504B4YCqOmoaSYYkKtMsE8jqzpPhNjfzp/haW+710LX\na0Tkx63ubUFfclpxCDezeWWkWaCUN/cALw3CknLa0Dhy2xSoRcRdKn23tNbE7qzN\nE0S3ySvdQwAl+mG5aWpYIxG3pzOPVnVZ9c0p10a3CitlttNCbxWyuHv77+ldU9U0\nWicCAwEAAaOB3DCB2TAdBgNVHQ4EFgQUrb2YejS0Jvf6xCZU7wO94CTLVBowCwYD\nVR0PBAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wgZkGA1UdIwSBkTCBjoAUrb2YejS0\nJvf6xCZU7wO94CTLVBqhc6RxMG8xCzAJBgNVBAYTAlNFMRQwEgYDVQQKEwtBZGRU\ncnVzdCBBQjEmMCQGA1UECxMdQWRkVHJ1c3QgRXh0ZXJuYWwgVFRQIE5ldHdvcmsx\nIjAgBgNVBAMTGUFkZFRydXN0IEV4dGVybmFsIENBIFJvb3SCAQEwDQYJKoZIhvcN\nAQEFBQADggEBALCb4IUlwtYj4g+WBpKdQZic2YR5gdkeWxQHIzZlj7DYd7usQWxH\nYINRsPkyPef89iYTx4AWpb9a/IfPeHmJIZriTAcKhjW88t5RxNKWt9x+Tu5w/Rw5\n6wwCURQtjr0W4MHfRnXnJK3s9EK0hZNwEGe6nQY1ShjTK3rMUUKhemPR5ruhxSvC\nNr4TDea9Y355e6cJDUCrat2PisP29owaQgVR1EX1n6diIWgVIEM8med8vSTYqZEX\nc4g/VhsxOBi0cQ+azcgOno4uG+GMmIPLHzHxREzGBHNJdmAPx/i9F4BrLunMTA5a\nmnkPIAou1Z5jJh5VkpTYghdae9C8x49OhgQ=\n-----END CERTIFICATE-----\n",
    }, 
    &CA{
        CommonName: "GeoTrust Global CA",
        Cert:       "-----BEGIN CERTIFICATE-----\nMIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT\nMRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i\nYWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG\nEwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg\nR2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9\n9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq\nfnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv\niS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU\n1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+\nbw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW\nMPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA\nephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l\nuMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn\nZ57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS\ntQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF\nPseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un\nhw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV\n5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==\n-----END CERTIFICATE-----\n",
    }, 
    &CA{
        CommonName: "Go Daddy Root Certificate Authority - G2",
        Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIBADANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMx\nEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoT\nEUdvRGFkZHkuY29tLCBJbmMuMTEwLwYDVQQDEyhHbyBEYWRkeSBSb290IENlcnRp\nZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIz\nNTk1OVowgYMxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQH\nEwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5LmNvbSwgSW5jLjExMC8GA1UE\nAxMoR28gRGFkZHkgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9xYgjx+lk09xvJGKP3gElY6SKD\nE6bFIEMBO4Tx5oVJnyfq9oQbTqC023CYxzIBsQU+B07u9PpPL1kwIuerGVZr4oAH\n/PMWdYA5UXvl+TW2dE6pjYIT5LY/qQOD+qK+ihVqf94Lw7YZFAXK6sOoBJQ7Rnwy\nDfMAZiLIjWltNowRGLfTshxgtDj6AozO091GB94KPutdfMh8+7ArU6SSYmlRJQVh\nGkSBjCypQ5Yj36w6gZoOKcUcqeldHraenjAKOc7xiID7S13MMuyFYkMlNAJWJwGR\ntDtwKj9useiciAF9n9T521NtYJ2/LOdYq7hfRvzOxBsDPAnrSTFcaUaz4EcCAwEA\nAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE\nFDqahQcQZyi27/a9BUFuIMGU2g/eMA0GCSqGSIb3DQEBCwUAA4IBAQCZ21151fmX\nWWcDYfF+OwYxdS2hII5PZYe096acvNjpL9DbWu7PdIxztDhC2gV7+AJ1uP2lsdeu\n9tfeE8tTEH6KRtGX+rcuKxGrkLAngPnon1rpN5+r5N9ss4UXnT3ZJE95kTXWXwTr\ngIOrmgIttRD02JDHBHNA7XIloKmf7J6raBKZV8aPEjoJpL1E/QYVN8Gb5DKj7Tjo\n2GTzLH4U/ALqn83/B2gX2yKQOC16jdFU8WnjXzPKej17CuPKf1855eJ1usV2GDPO\nLPAvTK33sefOT6jEm0pUBsV/fdUID+Ic/n4XuKxe9tQWskMJDE32p2u0mYRlynqI\n4uJEvlz36hz1\n-----END CERTIFICATE-----\n",
    }, 
}

var cloudflareMasquerades = []*client.Masquerade{ 
    &client.Masquerade{
        Domain:    "100partnerprogramme.de",
        IpAddress: "162.159.248.14",
    }, 
    &client.Masquerade{
        Domain:    "10minutemail.com",
        IpAddress: "162.159.250.16",
    }, 
    &client.Masquerade{
        Domain:    "1news.az",
        IpAddress: "162.159.240.30",
    }, 
    &client.Masquerade{
        Domain:    "2ch.hk",
        IpAddress: "104.20.22.31",
    }, 
    &client.Masquerade{
        Domain:    "a2hosting.com",
        IpAddress: "198.41.191.199",
    }, 
    &client.Masquerade{
        Domain:    "abs-cbnnews.com",
        IpAddress: "198.41.186.77",
    }, 
    &client.Masquerade{
        Domain:    "addmefast.com",
        IpAddress: "198.41.184.158",
    }, 
    &client.Masquerade{
        Domain:    "adf.ly",
        IpAddress: "104.20.0.4",
    }, 
    &client.Masquerade{
        Domain:    "adfoc.us",
        IpAddress: "162.159.255.16",
    }, 
    &client.Masquerade{
        Domain:    "adlure.net",
        IpAddress: "190.93.240.94",
    }, 
    &client.Masquerade{
        Domain:    "ads.id",
        IpAddress: "162.159.250.152",
    }, 
    &client.Masquerade{
        Domain:    "affiliatetechnology.com",
        IpAddress: "198.41.189.51",
    }, 
    &client.Masquerade{
        Domain:    "agentlk.com",
        IpAddress: "190.93.240.73",
    }, 
    &client.Masquerade{
        Domain:    "aitnews.com",
        IpAddress: "104.20.19.79",
    }, 
    &client.Masquerade{
        Domain:    "al-akhbar.com",
        IpAddress: "162.159.243.97",
    }, 
    &client.Masquerade{
        Domain:    "alexaboostup.com",
        IpAddress: "162.159.247.193",
    }, 
    &client.Masquerade{
        Domain:    "allanalpass.com",
        IpAddress: "162.159.244.34",
    }, 
    &client.Masquerade{
        Domain:    "allbusiness.com",
        IpAddress: "162.159.247.140",
    }, 
    &client.Masquerade{
        Domain:    "almasryalyoum.com",
        IpAddress: "141.101.113.103",
    }, 
    &client.Masquerade{
        Domain:    "alrakoba.net",
        IpAddress: "198.41.184.73",
    }, 
    &client.Masquerade{
        Domain:    "alwatanvoice.com",
        IpAddress: "162.159.255.143",
    }, 
    &client.Masquerade{
        Domain:    "amazinglytimedphotos.com",
        IpAddress: "198.41.185.180",
    }, 
    &client.Masquerade{
        Domain:    "amino.dk",
        IpAddress: "198.41.191.121",
    }, 
    &client.Masquerade{
        Domain:    "anakbnet.com",
        IpAddress: "162.159.250.168",
    }, 
    &client.Masquerade{
        Domain:    "anazahra.com",
        IpAddress: "162.159.254.7",
    }, 
    &client.Masquerade{
        Domain:    "any.gs",
        IpAddress: "162.159.240.58",
    }, 
    &client.Masquerade{
        Domain:    "aporrea.org",
        IpAddress: "108.162.202.29",
    }, 
    &client.Masquerade{
        Domain:    "appstorm.net",
        IpAddress: "162.159.243.165",
    }, 
    &client.Masquerade{
        Domain:    "aqarcity.com",
        IpAddress: "198.41.185.74",
    }, 
    &client.Masquerade{
        Domain:    "aqarmap.com",
        IpAddress: "162.159.250.95",
    }, 
    &client.Masquerade{
        Domain:    "arabi21.com",
        IpAddress: "108.162.202.13",
    }, 
    &client.Masquerade{
        Domain:    "arabnews.com",
        IpAddress: "108.162.203.20",
    }, 
    &client.Masquerade{
        Domain:    "arabseed.com",
        IpAddress: "198.41.185.132",
    }, 
    &client.Masquerade{
        Domain:    "arageek.com",
        IpAddress: "162.159.245.215",
    }, 
    &client.Masquerade{
        Domain:    "armorgames.com",
        IpAddress: "104.20.5.17",
    }, 
    &client.Masquerade{
        Domain:    "asianbookie.com",
        IpAddress: "162.159.250.133",
    }, 
    &client.Masquerade{
        Domain:    "asianwiki.com",
        IpAddress: "162.159.247.82",
    }, 
    &client.Masquerade{
        Domain:    "authorstream.com",
        IpAddress: "190.93.247.194",
    }, 
    &client.Masquerade{
        Domain:    "avaz.ba",
        IpAddress: "162.159.243.253",
    }, 
    &client.Masquerade{
        Domain:    "avpixlat.info",
        IpAddress: "141.101.112.138",
    }, 
    &client.Masquerade{
        Domain:    "axsam.az",
        IpAddress: "162.159.243.133",
    }, 
    &client.Masquerade{
        Domain:    "azvision.az",
        IpAddress: "162.159.243.148",
    }, 
    &client.Masquerade{
        Domain:    "b1.org",
        IpAddress: "162.159.243.39",
    }, 
    &client.Masquerade{
        Domain:    "babyou.com",
        IpAddress: "108.162.205.67",
    }, 
    &client.Masquerade{
        Domain:    "banahosting.com",
        IpAddress: "162.159.246.11",
    }, 
    &client.Masquerade{
        Domain:    "bannersbroker.com",
        IpAddress: "108.162.204.17",
    }, 
    &client.Masquerade{
        Domain:    "baykoreans.net",
        IpAddress: "190.93.241.11",
    }, 
    &client.Masquerade{
        Domain:    "bezuzyteczna.pl",
        IpAddress: "198.41.180.34",
    }, 
    &client.Masquerade{
        Domain:    "bikroy.com",
        IpAddress: "162.159.255.158",
    }, 
    &client.Masquerade{
        Domain:    "bittrex.com",
        IpAddress: "162.159.246.225",
    }, 
    &client.Masquerade{
        Domain:    "bizimyol.info",
        IpAddress: "190.93.240.19",
    }, 
    &client.Masquerade{
        Domain:    "blabbermouth.net",
        IpAddress: "162.159.247.184",
    }, 
    &client.Masquerade{
        Domain:    "bleepingcomputer.com",
        IpAddress: "141.101.112.117",
    }, 
    &client.Masquerade{
        Domain:    "blockchain.info",
        IpAddress: "190.93.243.195",
    }, 
    &client.Masquerade{
        Domain:    "bloody-disgusting.com",
        IpAddress: "162.159.248.220",
    }, 
    &client.Masquerade{
        Domain:    "brainstorm9.com.br",
        IpAddress: "162.159.251.96",
    }, 
    &client.Masquerade{
        Domain:    "btalah.com",
        IpAddress: "162.159.248.103",
    }, 
    &client.Masquerade{
        Domain:    "btc-e.com",
        IpAddress: "141.101.121.193",
    }, 
    &client.Masquerade{
        Domain:    "bubblews.com",
        IpAddress: "190.93.241.103",
    }, 
    &client.Masquerade{
        Domain:    "bugmenot.com",
        IpAddress: "162.159.248.51",
    }, 
    &client.Masquerade{
        Domain:    "bukkit.org",
        IpAddress: "190.93.246.100",
    }, 
    &client.Masquerade{
        Domain:    "businessinsider.com.au",
        IpAddress: "190.93.245.134",
    }, 
    &client.Masquerade{
        Domain:    "buzznews.asia",
        IpAddress: "198.41.186.124",
    }, 
    &client.Masquerade{
        Domain:    "buzzsumo.com",
        IpAddress: "108.162.201.208",
    }, 
    &client.Masquerade{
        Domain:    "cairokora.com",
        IpAddress: "104.16.1.117",
    }, 
    &client.Masquerade{
        Domain:    "canva.com",
        IpAddress: "162.159.245.88",
    }, 
    &client.Masquerade{
        Domain:    "careers360.com",
        IpAddress: "162.159.242.132",
    }, 
    &client.Masquerade{
        Domain:    "catracalivre.com.br",
        IpAddress: "198.41.247.124",
    }, 
    &client.Masquerade{
        Domain:    "cdn-cachefront.net",
        IpAddress: "162.159.245.124",
    }, 
    &client.Masquerade{
        Domain:    "censor.net.ua",
        IpAddress: "198.41.191.113",
    }, 
    &client.Masquerade{
        Domain:    "chinabuye.com",
        IpAddress: "198.41.184.203",
    }, 
    &client.Masquerade{
        Domain:    "cihan.com.tr",
        IpAddress: "104.16.3.7",
    }, 
    &client.Masquerade{
        Domain:    "cinetux.org",
        IpAddress: "162.159.251.123",
    }, 
    &client.Masquerade{
        Domain:    "cleanfiles.net",
        IpAddress: "190.93.243.46",
    }, 
    &client.Masquerade{
        Domain:    "clixsense.com",
        IpAddress: "198.41.188.40",
    }, 
    &client.Masquerade{
        Domain:    "cloudify.cc",
        IpAddress: "162.159.255.61",
    }, 
    &client.Masquerade{
        Domain:    "coinmarketcap.com",
        IpAddress: "198.41.249.182",
    }, 
    &client.Masquerade{
        Domain:    "col3negoriginal.lk",
        IpAddress: "141.101.113.10",
    }, 
    &client.Masquerade{
        Domain:    "collective-evolution.com",
        IpAddress: "198.41.189.248",
    }, 
    &client.Masquerade{
        Domain:    "com-2014.org",
        IpAddress: "162.159.241.96",
    }, 
    &client.Masquerade{
        Domain:    "conservativetribune.com",
        IpAddress: "162.159.242.147",
    }, 
    &client.Masquerade{
        Domain:    "conversionxl.com",
        IpAddress: "162.159.243.170",
    }, 
    &client.Masquerade{
        Domain:    "convinceandconvert.com",
        IpAddress: "141.101.124.136",
    }, 
    &client.Masquerade{
        Domain:    "copacet.com",
        IpAddress: "108.162.202.100",
    }, 
    &client.Masquerade{
        Domain:    "cpagrip.com",
        IpAddress: "198.41.187.139",
    }, 
    &client.Masquerade{
        Domain:    "cpasbien.pe",
        IpAddress: "104.16.15.124",
    }, 
    &client.Masquerade{
        Domain:    "cssmenumaker.com",
        IpAddress: "162.159.251.136",
    }, 
    &client.Masquerade{
        Domain:    "cuevana2.tv",
        IpAddress: "162.159.241.105",
    }, 
    &client.Masquerade{
        Domain:    "culturacolectiva.com",
        IpAddress: "162.159.240.99",
    }, 
    &client.Masquerade{
        Domain:    "curse.com",
        IpAddress: "190.93.246.101",
    }, 
    &client.Masquerade{
        Domain:    "cursecdn.com",
        IpAddress: "198.41.209.102",
    }, 
    &client.Masquerade{
        Domain:    "customer-poll.com",
        IpAddress: "190.93.246.140",
    }, 
    &client.Masquerade{
        Domain:    "dangerousminds.net",
        IpAddress: "108.162.203.197",
    }, 
    &client.Masquerade{
        Domain:    "datatables.net",
        IpAddress: "162.159.245.98",
    }, 
    &client.Masquerade{
        Domain:    "dealcatcher.com",
        IpAddress: "162.159.249.16",
    }, 
    &client.Masquerade{
        Domain:    "delivery-club.ru",
        IpAddress: "104.16.24.8",
    }, 
    &client.Masquerade{
        Domain:    "demotywatory.pl",
        IpAddress: "95.211.149.170",
    }, 
    &client.Masquerade{
        Domain:    "deperu.com",
        IpAddress: "162.159.240.213",
    }, 
    &client.Masquerade{
        Domain:    "designboom.com",
        IpAddress: "162.159.245.146",
    }, 
    &client.Masquerade{
        Domain:    "deutsche-wirtschafts-nachrichten.de",
        IpAddress: "198.41.186.52",
    }, 
    &client.Masquerade{
        Domain:    "diablofans.com",
        IpAddress: "198.41.208.102",
    }, 
    &client.Masquerade{
        Domain:    "digital-photography-school.com",
        IpAddress: "162.159.248.46",
    }, 
    &client.Masquerade{
        Domain:    "dnevnik.hr",
        IpAddress: "141.101.113.21",
    }, 
    &client.Masquerade{
        Domain:    "download-genius.com",
        IpAddress: "162.159.240.171",
    }, 
    &client.Masquerade{
        Domain:    "downloadming.nu",
        IpAddress: "198.41.184.77",
    }, 
    &client.Masquerade{
        Domain:    "dpstream.net",
        IpAddress: "198.41.191.151",
    }, 
    &client.Masquerade{
        Domain:    "drakulastream.eu",
        IpAddress: "162.159.248.189",
    }, 
    &client.Masquerade{
        Domain:    "drp.su",
        IpAddress: "162.159.243.17",
    }, 
    &client.Masquerade{
        Domain:    "dumpaday.com",
        IpAddress: "162.159.242.119",
    }, 
    &client.Masquerade{
        Domain:    "e-cigarette-forum.com",
        IpAddress: "198.41.186.238",
    }, 
    &client.Masquerade{
        Domain:    "e-monsite.com",
        IpAddress: "141.101.120.123",
    }, 
    &client.Masquerade{
        Domain:    "e-radio.gr",
        IpAddress: "198.41.183.19",
    }, 
    &client.Masquerade{
        Domain:    "eclypsia.com",
        IpAddress: "190.93.242.97",
    }, 
    &client.Masquerade{
        Domain:    "ecuavisa.com",
        IpAddress: "141.101.113.36",
    }, 
    &client.Masquerade{
        Domain:    "edublogs.org",
        IpAddress: "104.16.1.23",
    }, 
    &client.Masquerade{
        Domain:    "egaliteetreconciliation.fr",
        IpAddress: "190.93.243.80",
    }, 
    &client.Masquerade{
        Domain:    "egyup.com",
        IpAddress: "108.162.201.33",
    }, 
    &client.Masquerade{
        Domain:    "eharmony.com",
        IpAddress: "198.41.209.54",
    }, 
    &client.Masquerade{
        Domain:    "einthusan.com",
        IpAddress: "198.41.189.126",
    }, 
    &client.Masquerade{
        Domain:    "elakiri.com",
        IpAddress: "162.159.249.73",
    }, 
    &client.Masquerade{
        Domain:    "elhacker.net",
        IpAddress: "108.162.205.73",
    }, 
    &client.Masquerade{
        Domain:    "elwatannews.com",
        IpAddress: "190.93.240.93",
    }, 
    &client.Masquerade{
        Domain:    "en.bitcoin.it",
        IpAddress: "162.159.245.241",
    }, 
    &client.Masquerade{
        Domain:    "eslamoda.com",
        IpAddress: "162.159.255.119",
    }, 
    &client.Masquerade{
        Domain:    "esteghlali.com",
        IpAddress: "141.101.124.41",
    }, 
    &client.Masquerade{
        Domain:    "etorrent.co.kr",
        IpAddress: "198.41.185.120",
    }, 
    &client.Masquerade{
        Domain:    "eurostreaming.tv",
        IpAddress: "162.159.241.231",
    }, 
    &client.Masquerade{
        Domain:    "euw.leagueoflegends.com",
        IpAddress: "104.16.21.33",
    }, 
    &client.Masquerade{
        Domain:    "evozi.com",
        IpAddress: "198.41.202.14",
    }, 
    &client.Masquerade{
        Domain:    "explosm.net",
        IpAddress: "108.162.203.152",
    }, 
    &client.Masquerade{
        Domain:    "expressleech.com",
        IpAddress: "108.162.201.115",
    }, 
    &client.Masquerade{
        Domain:    "extratorrent.cc",
        IpAddress: "162.159.254.82",
    }, 
    &client.Masquerade{
        Domain:    "eztv.it",
        IpAddress: "108.162.200.14",
    }, 
    &client.Masquerade{
        Domain:    "faithtap.com",
        IpAddress: "198.41.188.57",
    }, 
    &client.Masquerade{
        Domain:    "famousbirthdays.com",
        IpAddress: "190.93.245.80",
    }, 
    &client.Masquerade{
        Domain:    "fasttech.com",
        IpAddress: "141.101.112.98",
    }, 
    &client.Masquerade{
        Domain:    "feedly.com",
        IpAddress: "162.159.253.4",
    }, 
    &client.Masquerade{
        Domain:    "filesfetcher.com",
        IpAddress: "198.41.186.168",
    }, 
    &client.Masquerade{
        Domain:    "filmesonlinegratis.net",
        IpAddress: "141.101.112.38",
    }, 
    &client.Masquerade{
        Domain:    "fiverr.com",
        IpAddress: "192.33.31.51",
    }, 
    &client.Masquerade{
        Domain:    "flashgames.it",
        IpAddress: "141.101.120.119",
    }, 
    &client.Masquerade{
        Domain:    "follow.net",
        IpAddress: "198.41.189.9",
    }, 
    &client.Masquerade{
        Domain:    "food52.com",
        IpAddress: "104.20.0.127",
    }, 
    &client.Masquerade{
        Domain:    "footballchannel.jp",
        IpAddress: "162.159.247.145",
    }, 
    &client.Masquerade{
        Domain:    "forbes.com.mx",
        IpAddress: "162.159.249.40",
    }, 
    &client.Masquerade{
        Domain:    "forexpeacearmy.com",
        IpAddress: "141.101.123.28",
    }, 
    &client.Masquerade{
        Domain:    "forgifs.com",
        IpAddress: "162.159.251.66",
    }, 
    &client.Masquerade{
        Domain:    "freebitco.in",
        IpAddress: "162.159.245.200",
    }, 
    &client.Masquerade{
        Domain:    "freedoge.co.in",
        IpAddress: "108.162.200.24",
    }, 
    &client.Masquerade{
        Domain:    "freemalaysiatoday.com",
        IpAddress: "162.159.248.43",
    }, 
    &client.Masquerade{
        Domain:    "freenode.net",
        IpAddress: "162.159.249.27",
    }, 
    &client.Masquerade{
        Domain:    "frontpage.fok.nl",
        IpAddress: "108.162.200.126",
    }, 
    &client.Masquerade{
        Domain:    "fshare.vn",
        IpAddress: "141.101.113.23",
    }, 
    &client.Masquerade{
        Domain:    "fsplay.net",
        IpAddress: "198.41.247.238",
    }, 
    &client.Masquerade{
        Domain:    "full-stream.net",
        IpAddress: "198.41.203.82",
    }, 
    &client.Masquerade{
        Domain:    "fun698.com",
        IpAddress: "198.41.186.185",
    }, 
    &client.Masquerade{
        Domain:    "funnymama.com",
        IpAddress: "198.41.249.64",
    }, 
    &client.Masquerade{
        Domain:    "futhead.com",
        IpAddress: "190.93.246.99",
    }, 
    &client.Masquerade{
        Domain:    "gahe.com",
        IpAddress: "162.159.252.233",
    }, 
    &client.Masquerade{
        Domain:    "gamebaby.com",
        IpAddress: "162.159.241.107",
    }, 
    &client.Masquerade{
        Domain:    "gameninja.com",
        IpAddress: "198.41.187.17",
    }, 
    &client.Masquerade{
        Domain:    "gamepedia.com",
        IpAddress: "190.93.244.101",
    }, 
    &client.Masquerade{
        Domain:    "games.co.id",
        IpAddress: "190.93.242.19",
    }, 
    &client.Masquerade{
        Domain:    "gamescaptain.com",
        IpAddress: "162.159.249.247",
    }, 
    &client.Masquerade{
        Domain:    "gameskwala.com",
        IpAddress: "162.159.241.227",
    }, 
    &client.Masquerade{
        Domain:    "gamingruff.com",
        IpAddress: "162.159.251.14",
    }, 
    &client.Masquerade{
        Domain:    "gazetatema.net",
        IpAddress: "198.41.249.104",
    }, 
    &client.Masquerade{
        Domain:    "gcflearnfree.org",
        IpAddress: "141.101.113.72",
    }, 
    &client.Masquerade{
        Domain:    "geo.tv",
        IpAddress: "190.93.244.11",
    }, 
    &client.Masquerade{
        Domain:    "getsecuredfiles.com",
        IpAddress: "162.159.245.76",
    }, 
    &client.Masquerade{
        Domain:    "getsoftfree.com",
        IpAddress: "162.159.248.115",
    }, 
    &client.Masquerade{
        Domain:    "gfxtra.net",
        IpAddress: "162.159.246.161",
    }, 
    &client.Masquerade{
        Domain:    "gfycat.com",
        IpAddress: "198.41.209.27",
    }, 
    &client.Masquerade{
        Domain:    "ghost.org",
        IpAddress: "190.93.246.19",
    }, 
    &client.Masquerade{
        Domain:    "gigacircle.com",
        IpAddress: "104.16.28.35",
    }, 
    &client.Masquerade{
        Domain:    "gilt.com",
        IpAddress: "198.41.209.111",
    }, 
    &client.Masquerade{
        Domain:    "gizmodo.com.au",
        IpAddress: "190.93.244.73",
    }, 
    &client.Masquerade{
        Domain:    "glamora.ma",
        IpAddress: "162.159.250.147",
    }, 
    &client.Masquerade{
        Domain:    "glassdoor.com",
        IpAddress: "190.93.244.224",
    }, 
    &client.Masquerade{
        Domain:    "globalresearch.ca",
        IpAddress: "162.159.247.162",
    }, 
    &client.Masquerade{
        Domain:    "goldentowns.com",
        IpAddress: "162.159.250.240",
    }, 
    &client.Masquerade{
        Domain:    "gooddrama.net",
        IpAddress: "108.162.203.51",
    }, 
    &client.Masquerade{
        Domain:    "goodmenproject.com",
        IpAddress: "162.159.249.216",
    }, 
    &client.Masquerade{
        Domain:    "goodsearch.com",
        IpAddress: "141.101.123.98",
    }, 
    &client.Masquerade{
        Domain:    "gooool.org",
        IpAddress: "162.159.243.194",
    }, 
    &client.Masquerade{
        Domain:    "gosugamers.net",
        IpAddress: "162.159.240.238",
    }, 
    &client.Masquerade{
        Domain:    "gottabemobile.com",
        IpAddress: "190.93.242.110",
    }, 
    &client.Masquerade{
        Domain:    "graphpaperpress.com",
        IpAddress: "162.159.250.94",
    }, 
    &client.Masquerade{
        Domain:    "gtspirit.com",
        IpAddress: "162.159.243.151",
    }, 
    &client.Masquerade{
        Domain:    "guardianlv.com",
        IpAddress: "162.159.249.39",
    }, 
    &client.Masquerade{
        Domain:    "gurufocus.com",
        IpAddress: "162.159.251.182",
    }, 
    &client.Masquerade{
        Domain:    "haber1903.com",
        IpAddress: "108.162.201.135",
    }, 
    &client.Masquerade{
        Domain:    "haber61.net",
        IpAddress: "141.101.126.44",
    }, 
    &client.Masquerade{
        Domain:    "hackforums.net",
        IpAddress: "141.101.121.11",
    }, 
    &client.Masquerade{
        Domain:    "haqqin.az",
        IpAddress: "198.41.189.53",
    }, 
    &client.Masquerade{
        Domain:    "hardmob.com.br",
        IpAddress: "190.93.241.96",
    }, 
    &client.Masquerade{
        Domain:    "hearthpwn.com",
        IpAddress: "190.93.247.113",
    }, 
    &client.Masquerade{
        Domain:    "hesport.com",
        IpAddress: "162.159.242.209",
    }, 
    &client.Masquerade{
        Domain:    "hibapress.com",
        IpAddress: "162.159.245.178",
    }, 
    &client.Masquerade{
        Domain:    "highcharts.com",
        IpAddress: "162.159.250.193",
    }, 
    &client.Masquerade{
        Domain:    "hitleap.com",
        IpAddress: "198.41.182.88",
    }, 
    &client.Masquerade{
        Domain:    "hltv.org",
        IpAddress: "162.159.241.196",
    }, 
    &client.Masquerade{
        Domain:    "hobbyking.com",
        IpAddress: "141.101.112.125",
    }, 
    &client.Masquerade{
        Domain:    "home.ijreview.com",
        IpAddress: "104.16.3.43",
    }, 
    &client.Masquerade{
        Domain:    "i-fit.com.tw",
        IpAddress: "108.162.202.108",
    }, 
    &client.Masquerade{
        Domain:    "ibuildapp.com",
        IpAddress: "141.101.113.201",
    }, 
    &client.Masquerade{
        Domain:    "ifilez.org",
        IpAddress: "141.101.112.94",
    }, 
    &client.Masquerade{
        Domain:    "iitv.info",
        IpAddress: "198.41.249.221",
    }, 
    &client.Masquerade{
        Domain:    "ikman.lk",
        IpAddress: "198.41.249.242",
    }, 
    &client.Masquerade{
        Domain:    "imagetwist.com",
        IpAddress: "162.159.240.244",
    }, 
    &client.Masquerade{
        Domain:    "imgchili.net",
        IpAddress: "162.159.249.105",
    }, 
    &client.Masquerade{
        Domain:    "imgflip.com",
        IpAddress: "141.101.114.143",
    }, 
    &client.Masquerade{
        Domain:    "imgspice.com",
        IpAddress: "198.41.249.212",
    }, 
    &client.Masquerade{
        Domain:    "imscrapidmailer.com",
        IpAddress: "162.159.249.226",
    }, 
    &client.Masquerade{
        Domain:    "imsuccesscenter.com",
        IpAddress: "162.159.251.79",
    }, 
    &client.Masquerade{
        Domain:    "indeksonline.net",
        IpAddress: "190.93.254.155",
    }, 
    &client.Masquerade{
        Domain:    "index.hr",
        IpAddress: "198.41.176.5",
    }, 
    &client.Masquerade{
        Domain:    "inflexwetrust.com",
        IpAddress: "162.159.250.202",
    }, 
    &client.Masquerade{
        Domain:    "inforesist.org",
        IpAddress: "108.162.205.29",
    }, 
    &client.Masquerade{
        Domain:    "informe21.com",
        IpAddress: "162.159.244.121",
    }, 
    &client.Masquerade{
        Domain:    "intercambiosvirtuales.org",
        IpAddress: "162.159.243.146",
    }, 
    &client.Masquerade{
        Domain:    "ionicframework.com",
        IpAddress: "162.159.248.203",
    }, 
    &client.Masquerade{
        Domain:    "ipiccy.com",
        IpAddress: "141.101.123.33",
    }, 
    &client.Masquerade{
        Domain:    "iplocation.net",
        IpAddress: "162.159.242.87",
    }, 
    &client.Masquerade{
        Domain:    "iptorrents.com",
        IpAddress: "190.93.243.131",
    }, 
    &client.Masquerade{
        Domain:    "israelvideonetwork.com",
        IpAddress: "198.41.185.73",
    }, 
    &client.Masquerade{
        Domain:    "italia-film.org",
        IpAddress: "190.93.241.91",
    }, 
    &client.Masquerade{
        Domain:    "iwebchk.com",
        IpAddress: "162.159.241.191",
    }, 
    &client.Masquerade{
        Domain:    "ixl.com",
        IpAddress: "190.93.246.136",
    }, 
    &client.Masquerade{
        Domain:    "j.gs",
        IpAddress: "162.159.251.35",
    }, 
    &client.Masquerade{
        Domain:    "jamiiforums.com",
        IpAddress: "162.159.241.71",
    }, 
    &client.Masquerade{
        Domain:    "jeuneafrique.com",
        IpAddress: "162.159.249.152",
    }, 
    &client.Masquerade{
        Domain:    "joomla.fr",
        IpAddress: "162.159.246.52",
    }, 
    &client.Masquerade{
        Domain:    "jquery.com",
        IpAddress: "104.16.14.15",
    }, 
    &client.Masquerade{
        Domain:    "jquerymobile.com",
        IpAddress: "104.16.11.13",
    }, 
    &client.Masquerade{
        Domain:    "jqueryui.com",
        IpAddress: "104.16.2.14",
    }, 
    &client.Masquerade{
        Domain:    "jumia.com.ng",
        IpAddress: "198.41.188.216",
    }, 
    &client.Masquerade{
        Domain:    "k2s.cc",
        IpAddress: "162.159.245.42",
    }, 
    &client.Masquerade{
        Domain:    "karatbars.com",
        IpAddress: "162.159.242.93",
    }, 
    &client.Masquerade{
        Domain:    "karnaval.com",
        IpAddress: "141.101.121.195",
    }, 
    &client.Masquerade{
        Domain:    "kaymu.com.ng",
        IpAddress: "104.20.26.2",
    }, 
    &client.Masquerade{
        Domain:    "kaymu.pk",
        IpAddress: "141.101.113.175",
    }, 
    &client.Masquerade{
        Domain:    "keywordtool.io",
        IpAddress: "162.159.244.204",
    }, 
    &client.Masquerade{
        Domain:    "kickerdaily.com",
        IpAddress: "162.159.241.39",
    }, 
    &client.Masquerade{
        Domain:    "kidsactivitiesblog.com",
        IpAddress: "162.159.247.80",
    }, 
    &client.Masquerade{
        Domain:    "kinogo.net",
        IpAddress: "190.93.241.114",
    }, 
    &client.Masquerade{
        Domain:    "kinoman.tv",
        IpAddress: "198.41.186.174",
    }, 
    &client.Masquerade{
        Domain:    "klix.ba",
        IpAddress: "141.101.112.88",
    }, 
    &client.Masquerade{
        Domain:    "korben.info",
        IpAddress: "162.159.250.186",
    }, 
    &client.Masquerade{
        Domain:    "kwejk.pl",
        IpAddress: "162.159.255.38",
    }, 
    &client.Masquerade{
        Domain:    "ladygames.com",
        IpAddress: "162.159.242.107",
    }, 
    &client.Masquerade{
        Domain:    "lamido.co.id",
        IpAddress: "198.41.188.224",
    }, 
    &client.Masquerade{
        Domain:    "lapatilla.com",
        IpAddress: "141.101.123.240",
    }, 
    &client.Masquerade{
        Domain:    "lasvegassun.com",
        IpAddress: "141.101.123.129",
    }, 
    &client.Masquerade{
        Domain:    "laughingsquid.com",
        IpAddress: "162.159.247.97",
    }, 
    &client.Masquerade{
        Domain:    "lbcgroup.tv",
        IpAddress: "141.101.112.51",
    }, 
    &client.Masquerade{
        Domain:    "legacyclix.com",
        IpAddress: "162.159.250.65",
    }, 
    &client.Masquerade{
        Domain:    "legiaodosherois.com.br",
        IpAddress: "162.159.245.5",
    }, 
    &client.Masquerade{
        Domain:    "libertyland.tv",
        IpAddress: "162.159.255.101",
    }, 
    &client.Masquerade{
        Domain:    "lifebuzz.com",
        IpAddress: "162.159.242.246",
    }, 
    &client.Masquerade{
        Domain:    "lifehacker.com.au",
        IpAddress: "190.93.247.73",
    }, 
    &client.Masquerade{
        Domain:    "likemag.com",
        IpAddress: "162.159.251.215",
    }, 
    &client.Masquerade{
        Domain:    "likes.com",
        IpAddress: "141.101.115.34",
    }, 
    &client.Masquerade{
        Domain:    "listenpersian.net",
        IpAddress: "198.41.249.9",
    }, 
    &client.Masquerade{
        Domain:    "livefootballol.com",
        IpAddress: "162.159.246.67",
    }, 
    &client.Masquerade{
        Domain:    "livefootballvideo.com",
        IpAddress: "108.162.202.76",
    }, 
    &client.Masquerade{
        Domain:    "localbitcoins.com",
        IpAddress: "104.20.31.3",
    }, 
    &client.Masquerade{
        Domain:    "lowendbox.com",
        IpAddress: "141.101.113.78",
    }, 
    &client.Masquerade{
        Domain:    "lowendtalk.com",
        IpAddress: "190.93.241.77",
    }, 
    &client.Masquerade{
        Domain:    "maannews.net",
        IpAddress: "198.41.180.81",
    }, 
    &client.Masquerade{
        Domain:    "macacovelho.com.br",
        IpAddress: "198.41.188.108",
    }, 
    &client.Masquerade{
        Domain:    "macworld.co.uk",
        IpAddress: "104.16.14.54",
    }, 
    &client.Masquerade{
        Domain:    "madmimi.com",
        IpAddress: "141.101.123.192",
    }, 
    &client.Masquerade{
        Domain:    "mafiashare.net",
        IpAddress: "141.101.120.97",
    }, 
    &client.Masquerade{
        Domain:    "makeagif.com",
        IpAddress: "162.159.249.46",
    }, 
    &client.Masquerade{
        Domain:    "makeupandbeauty.com",
        IpAddress: "162.159.241.54",
    }, 
    &client.Masquerade{
        Domain:    "makezine.com",
        IpAddress: "108.162.206.21",
    }, 
    &client.Masquerade{
        Domain:    "mamamia.com.au",
        IpAddress: "162.159.244.187",
    }, 
    &client.Masquerade{
        Domain:    "manicomio-share.com",
        IpAddress: "162.159.247.208",
    }, 
    &client.Masquerade{
        Domain:    "manygames.com",
        IpAddress: "162.159.242.107",
    }, 
    &client.Masquerade{
        Domain:    "maplestage.com",
        IpAddress: "162.159.255.194",
    }, 
    &client.Masquerade{
        Domain:    "marketinggenesis.com",
        IpAddress: "162.159.250.110",
    }, 
    &client.Masquerade{
        Domain:    "marunadanmalayali.com",
        IpAddress: "141.101.126.226",
    }, 
    &client.Masquerade{
        Domain:    "matchesfashion.com",
        IpAddress: "198.41.184.14",
    }, 
    &client.Masquerade{
        Domain:    "mazika2day.com",
        IpAddress: "198.41.190.107",
    }, 
    &client.Masquerade{
        Domain:    "media-fire.org",
        IpAddress: "198.41.188.89",
    }, 
    &client.Masquerade{
        Domain:    "medialoot.com",
        IpAddress: "162.159.241.192",
    }, 
    &client.Masquerade{
        Domain:    "megafilmeshd.net",
        IpAddress: "198.41.188.137",
    }, 
    &client.Masquerade{
        Domain:    "mg.co.za",
        IpAddress: "162.159.245.60",
    }, 
    &client.Masquerade{
        Domain:    "microworkers.com",
        IpAddress: "141.101.112.148",
    }, 
    &client.Masquerade{
        Domain:    "minecraftforum.net",
        IpAddress: "141.101.114.118",
    }, 
    &client.Masquerade{
        Domain:    "minecraftservers.org",
        IpAddress: "190.93.242.14",
    }, 
    &client.Masquerade{
        Domain:    "missmalini.com",
        IpAddress: "162.159.251.41",
    }, 
    &client.Masquerade{
        Domain:    "mixedmartialarts.com",
        IpAddress: "141.101.113.57",
    }, 
    &client.Masquerade{
        Domain:    "mixergy.com",
        IpAddress: "198.41.249.147",
    }, 
    &client.Masquerade{
        Domain:    "mmo-champion.com",
        IpAddress: "190.93.246.118",
    }, 
    &client.Masquerade{
        Domain:    "mo.gov",
        IpAddress: "104.16.24.39",
    }, 
    &client.Masquerade{
        Domain:    "mobafire.com",
        IpAddress: "141.101.121.23",
    }, 
    &client.Masquerade{
        Domain:    "modern.az",
        IpAddress: "108.162.205.159",
    }, 
    &client.Masquerade{
        Domain:    "moneyplatform.biz",
        IpAddress: "108.162.202.215",
    }, 
    &client.Masquerade{
        Domain:    "monitorbacklinks.com",
        IpAddress: "198.41.249.24",
    }, 
    &client.Masquerade{
        Domain:    "morguefile.com",
        IpAddress: "162.159.247.132",
    }, 
    &client.Masquerade{
        Domain:    "mp3olimp.net",
        IpAddress: "162.159.248.237",
    }, 
    &client.Masquerade{
        Domain:    "mylikes.com",
        IpAddress: "141.101.115.38",
    }, 
    &client.Masquerade{
        Domain:    "naijaloaded.com.ng",
        IpAddress: "141.101.127.195",
    }, 
    &client.Masquerade{
        Domain:    "nairaland.com",
        IpAddress: "198.41.190.67",
    }, 
    &client.Masquerade{
        Domain:    "naosalvo.com.br",
        IpAddress: "108.162.207.184",
    }, 
    &client.Masquerade{
        Domain:    "nbadraft.net",
        IpAddress: "162.159.250.170",
    }, 
    &client.Masquerade{
        Domain:    "nerdfitness.com",
        IpAddress: "162.159.243.153",
    }, 
    &client.Masquerade{
        Domain:    "network-tools.com",
        IpAddress: "141.101.123.110",
    }, 
    &client.Masquerade{
        Domain:    "network54.com",
        IpAddress: "162.159.250.43",
    }, 
    &client.Masquerade{
        Domain:    "new.elfagr.org",
        IpAddress: "198.41.191.53",
    }, 
    &client.Masquerade{
        Domain:    "newcoupons.info",
        IpAddress: "108.162.200.39",
    }, 
    &client.Masquerade{
        Domain:    "newmobilelife.com",
        IpAddress: "108.162.207.54",
    }, 
    &client.Masquerade{
        Domain:    "nextinpact.com",
        IpAddress: "162.159.249.65",
    }, 
    &client.Masquerade{
        Domain:    "nextmedia.com",
        IpAddress: "104.16.9.5",
    }, 
    &client.Masquerade{
        Domain:    "ngrguardiannews.com",
        IpAddress: "162.159.240.185",
    }, 
    &client.Masquerade{
        Domain:    "niebezpiecznik.pl",
        IpAddress: "198.41.203.16",
    }, 
    &client.Masquerade{
        Domain:    "noticiaaldia.com",
        IpAddress: "198.41.179.92",
    }, 
    &client.Masquerade{
        Domain:    "noticierodigital.com",
        IpAddress: "141.101.112.96",
    }, 
    &client.Masquerade{
        Domain:    "ocioso.com.br",
        IpAddress: "108.162.204.94",
    }, 
    &client.Masquerade{
        Domain:    "officegeteasy.com",
        IpAddress: "108.162.206.208",
    }, 
    &client.Masquerade{
        Domain:    "ojooo.com",
        IpAddress: "198.41.189.230",
    }, 
    &client.Masquerade{
        Domain:    "omgtorrent.com",
        IpAddress: "198.41.200.19",
    }, 
    &client.Masquerade{
        Domain:    "onegreenplanet.org",
        IpAddress: "162.159.243.192",
    }, 
    &client.Masquerade{
        Domain:    "oneplus.net",
        IpAddress: "141.101.125.10",
    }, 
    &client.Masquerade{
        Domain:    "onlineclock.net",
        IpAddress: "190.93.242.58",
    }, 
    &client.Masquerade{
        Domain:    "onlinesoccermanager.com",
        IpAddress: "162.159.255.17",
    }, 
    &client.Masquerade{
        Domain:    "opencart.com",
        IpAddress: "104.20.14.19",
    }, 
    &client.Masquerade{
        Domain:    "opensoftwareupdater.com",
        IpAddress: "190.93.255.159",
    }, 
    &client.Masquerade{
        Domain:    "opposingviews.com",
        IpAddress: "162.159.253.201",
    }, 
    &client.Masquerade{
        Domain:    "optionow.com",
        IpAddress: "141.101.123.94",
    }, 
    &client.Masquerade{
        Domain:    "oscaro.com",
        IpAddress: "104.16.9.97",
    }, 
    &client.Masquerade{
        Domain:    "osdir.com",
        IpAddress: "162.159.254.185",
    }, 
    &client.Masquerade{
        Domain:    "oyunkolu.com",
        IpAddress: "162.159.248.209",
    }, 
    &client.Masquerade{
        Domain:    "palemoon.org",
        IpAddress: "162.159.255.211",
    }, 
    &client.Masquerade{
        Domain:    "pangu.io",
        IpAddress: "108.162.201.127",
    }, 
    &client.Masquerade{
        Domain:    "parimatch.com",
        IpAddress: "198.41.185.98",
    }, 
    &client.Masquerade{
        Domain:    "partis.si",
        IpAddress: "108.162.201.127",
    }, 
    &client.Masquerade{
        Domain:    "pastebin.com",
        IpAddress: "190.93.241.15",
    }, 
    &client.Masquerade{
        Domain:    "pcadvisor.co.uk",
        IpAddress: "104.16.28.51",
    }, 
    &client.Masquerade{
        Domain:    "pelis24.com",
        IpAddress: "198.41.190.143",
    }, 
    &client.Masquerade{
        Domain:    "photoyoum7.com",
        IpAddress: "104.16.4.117",
    }, 
    &client.Masquerade{
        Domain:    "pijamasurf.com",
        IpAddress: "162.159.242.249",
    }, 
    &client.Masquerade{
        Domain:    "piktochart.com",
        IpAddress: "162.159.246.70",
    }, 
    &client.Masquerade{
        Domain:    "pixroute.com",
        IpAddress: "162.159.242.52",
    }, 
    &client.Masquerade{
        Domain:    "planetminecraft.com",
        IpAddress: "141.101.113.126",
    }, 
    &client.Masquerade{
        Domain:    "playit.pk",
        IpAddress: "162.159.240.198",
    }, 
    &client.Masquerade{
        Domain:    "plp.cl",
        IpAddress: "198.41.200.28",
    }, 
    &client.Masquerade{
        Domain:    "podomatic.com",
        IpAddress: "104.20.21.4",
    }, 
    &client.Masquerade{
        Domain:    "podrobnosti.ua",
        IpAddress: "198.41.178.97",
    }, 
    &client.Masquerade{
        Domain:    "popcash.net",
        IpAddress: "162.159.244.37",
    }, 
    &client.Masquerade{
        Domain:    "popnhop.com",
        IpAddress: "162.159.248.205",
    }, 
    &client.Masquerade{
        Domain:    "post852.com",
        IpAddress: "198.41.188.113",
    }, 
    &client.Masquerade{
        Domain:    "postcron.com",
        IpAddress: "162.159.242.38",
    }, 
    &client.Masquerade{
        Domain:    "postto.me",
        IpAddress: "141.101.120.156",
    }, 
    &client.Masquerade{
        Domain:    "powvideo.net",
        IpAddress: "190.93.255.95",
    }, 
    &client.Masquerade{
        Domain:    "premium.wpmudev.org",
        IpAddress: "104.16.24.10",
    }, 
    &client.Masquerade{
        Domain:    "premiumwp.com",
        IpAddress: "162.159.251.100",
    }, 
    &client.Masquerade{
        Domain:    "prensa.com",
        IpAddress: "162.159.254.69",
    }, 
    &client.Masquerade{
        Domain:    "prlog.ru",
        IpAddress: "162.159.242.63",
    }, 
    &client.Masquerade{
        Domain:    "prntscr.com",
        IpAddress: "198.41.191.131",
    }, 
    &client.Masquerade{
        Domain:    "proprofs.com",
        IpAddress: "198.41.204.34",
    }, 
    &client.Masquerade{
        Domain:    "prosperent.com",
        IpAddress: "162.159.241.24",
    }, 
    &client.Masquerade{
        Domain:    "proteusthemes.com",
        IpAddress: "162.159.247.215",
    }, 
    &client.Masquerade{
        Domain:    "ptcstair.com",
        IpAddress: "162.159.249.107",
    }, 
    &client.Masquerade{
        Domain:    "puu.sh",
        IpAddress: "162.159.243.139",
    }, 
    &client.Masquerade{
        Domain:    "q.gs",
        IpAddress: "162.159.247.88",
    }, 
    &client.Masquerade{
        Domain:    "qafqazinfo.az",
        IpAddress: "162.159.245.58",
    }, 
    &client.Masquerade{
        Domain:    "qatarliving.com",
        IpAddress: "198.41.249.175",
    }, 
    &client.Masquerade{
        Domain:    "qol.az",
        IpAddress: "162.159.244.133",
    }, 
    &client.Masquerade{
        Domain:    "r10.net",
        IpAddress: "162.159.252.82",
    }, 
    &client.Masquerade{
        Domain:    "rapgenius.com",
        IpAddress: "104.16.27.4",
    }, 
    &client.Masquerade{
        Domain:    "rapradar.com",
        IpAddress: "190.93.243.15",
    }, 
    &client.Masquerade{
        Domain:    "rassd.com",
        IpAddress: "162.159.253.222",
    }, 
    &client.Masquerade{
        Domain:    "rcwlightning.com",
        IpAddress: "108.162.200.227",
    }, 
    &client.Masquerade{
        Domain:    "re-direcciona.me",
        IpAddress: "162.159.242.146",
    }, 
    &client.Masquerade{
        Domain:    "repelis.tv",
        IpAddress: "162.159.246.193",
    }, 
    &client.Masquerade{
        Domain:    "reshareworthy.com",
        IpAddress: "141.101.127.122",
    }, 
    &client.Masquerade{
        Domain:    "ritegamer.com",
        IpAddress: "162.159.250.247",
    }, 
    &client.Masquerade{
        Domain:    "riverplate.com",
        IpAddress: "162.159.244.32",
    }, 
    &client.Masquerade{
        Domain:    "rollingout.com",
        IpAddress: "198.41.185.117",
    }, 
    &client.Masquerade{
        Domain:    "rsw-systems.com",
        IpAddress: "198.41.191.70",
    }, 
    &client.Masquerade{
        Domain:    "rudaw.net",
        IpAddress: "190.93.242.83",
    }, 
    &client.Masquerade{
        Domain:    "rus.ec",
        IpAddress: "198.41.185.201",
    }, 
    &client.Masquerade{
        Domain:    "rusvesna.su",
        IpAddress: "190.93.248.92",
    }, 
    &client.Masquerade{
        Domain:    "sa.ae",
        IpAddress: "162.159.240.111",
    }, 
    &client.Masquerade{
        Domain:    "saaid.net",
        IpAddress: "198.41.178.75",
    }, 
    &client.Masquerade{
        Domain:    "sabq.org",
        IpAddress: "141.101.115.116",
    }, 
    &client.Masquerade{
        Domain:    "sanakirja.org",
        IpAddress: "190.93.240.90",
    }, 
    &client.Masquerade{
        Domain:    "sayidaty.net",
        IpAddress: "108.162.201.30",
    }, 
    &client.Masquerade{
        Domain:    "scotch.io",
        IpAddress: "141.101.125.86",
    }, 
    &client.Masquerade{
        Domain:    "searchengines.guru",
        IpAddress: "190.93.240.113",
    }, 
    &client.Masquerade{
        Domain:    "searchengines.ru",
        IpAddress: "141.101.123.113",
    }, 
    &client.Masquerade{
        Domain:    "seemorgh.com",
        IpAddress: "141.101.120.194",
    }, 
    &client.Masquerade{
        Domain:    "sendgrid.com",
        IpAddress: "104.20.21.26",
    }, 
    &client.Masquerade{
        Domain:    "sergey-mavrodi-mmm.net",
        IpAddress: "162.159.244.38",
    }, 
    &client.Masquerade{
        Domain:    "sergey-mavrodi-mmm.org",
        IpAddress: "162.159.251.160",
    }, 
    &client.Masquerade{
        Domain:    "sergey-mavrodi.com",
        IpAddress: "162.159.253.253",
    }, 
    &client.Masquerade{
        Domain:    "sergeymavrodi.com",
        IpAddress: "162.159.255.203",
    }, 
    &client.Masquerade{
        Domain:    "shahiya.com",
        IpAddress: "162.159.241.128",
    }, 
    &client.Masquerade{
        Domain:    "shapeways.com",
        IpAddress: "198.41.189.36",
    }, 
    &client.Masquerade{
        Domain:    "sheknows.com",
        IpAddress: "162.159.243.215",
    }, 
    &client.Masquerade{
        Domain:    "shippuden.tv",
        IpAddress: "108.162.205.85",
    }, 
    &client.Masquerade{
        Domain:    "shmoop.com",
        IpAddress: "190.93.241.48",
    }, 
    &client.Masquerade{
        Domain:    "siam-movie.com",
        IpAddress: "198.41.182.78",
    }, 
    &client.Masquerade{
        Domain:    "siliconera.com",
        IpAddress: "190.93.247.99",
    }, 
    &client.Masquerade{
        Domain:    "siliconrus.com",
        IpAddress: "198.41.191.66",
    }, 
    &client.Masquerade{
        Domain:    "sinchew.com.my",
        IpAddress: "141.101.121.130",
    }, 
    &client.Masquerade{
        Domain:    "sitetalk.com",
        IpAddress: "190.93.241.207",
    }, 
    &client.Masquerade{
        Domain:    "skladchik.com",
        IpAddress: "104.20.3.89",
    }, 
    &client.Masquerade{
        Domain:    "smallpdf.com",
        IpAddress: "162.159.249.205",
    }, 
    &client.Masquerade{
        Domain:    "smartpassiveincome.com",
        IpAddress: "162.159.243.132",
    }, 
    &client.Masquerade{
        Domain:    "smittenkitchen.com",
        IpAddress: "141.101.112.139",
    }, 
    &client.Masquerade{
        Domain:    "smofast.com",
        IpAddress: "141.101.124.55",
    }, 
    &client.Masquerade{
        Domain:    "smosh.com",
        IpAddress: "162.159.254.34",
    }, 
    &client.Masquerade{
        Domain:    "smotrisport.tv",
        IpAddress: "198.41.176.23",
    }, 
    &client.Masquerade{
        Domain:    "snapengage.com",
        IpAddress: "141.101.113.133",
    }, 
    &client.Masquerade{
        Domain:    "snapwidget.com",
        IpAddress: "162.159.246.49",
    }, 
    &client.Masquerade{
        Domain:    "snip.ly",
        IpAddress: "108.162.202.204",
    }, 
    &client.Masquerade{
        Domain:    "snipplr.com",
        IpAddress: "162.159.250.66",
    }, 
    &client.Masquerade{
        Domain:    "softarchive.net",
        IpAddress: "108.162.202.222",
    }, 
    &client.Masquerade{
        Domain:    "somuch.com",
        IpAddress: "141.101.127.228",
    }, 
    &client.Masquerade{
        Domain:    "songspk.name",
        IpAddress: "108.162.202.183",
    }, 
    &client.Masquerade{
        Domain:    "soompi.com",
        IpAddress: "104.20.19.19",
    }, 
    &client.Masquerade{
        Domain:    "sooperarticles.com",
        IpAddress: "108.162.205.236",
    }, 
    &client.Masquerade{
        Domain:    "sott.net",
        IpAddress: "162.159.250.111",
    }, 
    &client.Masquerade{
        Domain:    "spi0n.com",
        IpAddress: "198.41.181.58",
    }, 
    &client.Masquerade{
        Domain:    "sportbox.az",
        IpAddress: "108.162.206.207",
    }, 
    &client.Masquerade{
        Domain:    "sprotyv.info",
        IpAddress: "141.101.126.17",
    }, 
    &client.Masquerade{
        Domain:    "stadt-bremerhaven.de",
        IpAddress: "198.41.191.15",
    }, 
    &client.Masquerade{
        Domain:    "stagram.com",
        IpAddress: "190.93.240.45",
    }, 
    &client.Masquerade{
        Domain:    "stansberryresearch.com",
        IpAddress: "104.20.26.17",
    }, 
    &client.Masquerade{
        Domain:    "steamdb.info",
        IpAddress: "162.159.254.177",
    }, 
    &client.Masquerade{
        Domain:    "streamallthis.me",
        IpAddress: "162.159.242.171",
    }, 
    &client.Masquerade{
        Domain:    "subscene.com",
        IpAddress: "162.159.249.9",
    }, 
    &client.Masquerade{
        Domain:    "sudaneseonline.com",
        IpAddress: "198.41.205.254",
    }, 
    &client.Masquerade{
        Domain:    "super.ae",
        IpAddress: "162.159.254.6",
    }, 
    &client.Masquerade{
        Domain:    "survzilla.com",
        IpAddress: "108.162.201.107",
    }, 
    &client.Masquerade{
        Domain:    "t24.com.tr",
        IpAddress: "141.101.125.79",
    }, 
    &client.Masquerade{
        Domain:    "tahrirnews.com",
        IpAddress: "198.41.191.205",
    }, 
    &client.Masquerade{
        Domain:    "tarafdari.com",
        IpAddress: "198.41.190.174",
    }, 
    &client.Masquerade{
        Domain:    "tecnoblog.net",
        IpAddress: "108.162.206.195",
    }, 
    &client.Masquerade{
        Domain:    "teebik.com",
        IpAddress: "198.41.187.108",
    }, 
    &client.Masquerade{
        Domain:    "templatemonster.com",
        IpAddress: "198.41.187.147",
    }, 
    &client.Masquerade{
        Domain:    "temptalia.com",
        IpAddress: "108.162.200.113",
    }, 
    &client.Masquerade{
        Domain:    "terafile.co",
        IpAddress: "162.159.250.139",
    }, 
    &client.Masquerade{
        Domain:    "tert.am",
        IpAddress: "108.162.202.195",
    }, 
    &client.Masquerade{
        Domain:    "teveonline.net",
        IpAddress: "108.162.205.133",
    }, 
    &client.Masquerade{
        Domain:    "the-open-mind.com",
        IpAddress: "141.101.126.65",
    }, 
    &client.Masquerade{
        Domain:    "thebot.net",
        IpAddress: "162.159.249.116",
    }, 
    &client.Masquerade{
        Domain:    "thediplomat.com",
        IpAddress: "162.159.240.235",
    }, 
    &client.Masquerade{
        Domain:    "thedirty.com",
        IpAddress: "190.93.240.32",
    }, 
    &client.Masquerade{
        Domain:    "thefile.me",
        IpAddress: "162.159.252.33",
    }, 
    &client.Masquerade{
        Domain:    "thefreethoughtproject.com",
        IpAddress: "198.41.249.156",
    }, 
    &client.Masquerade{
        Domain:    "thehackernews.com",
        IpAddress: "162.159.246.166",
    }, 
    &client.Masquerade{
        Domain:    "theladbible.com",
        IpAddress: "198.41.214.5",
    }, 
    &client.Masquerade{
        Domain:    "themattwalshblog.com",
        IpAddress: "108.162.204.50",
    }, 
    &client.Masquerade{
        Domain:    "theme-fusion.com",
        IpAddress: "162.159.245.243",
    }, 
    &client.Masquerade{
        Domain:    "thenationonlineng.net",
        IpAddress: "162.159.253.179",
    }, 
    &client.Masquerade{
        Domain:    "thenewstribe.com",
        IpAddress: "162.159.246.82",
    }, 
    &client.Masquerade{
        Domain:    "thepioneerwoman.com",
        IpAddress: "198.41.186.138",
    }, 
    &client.Masquerade{
        Domain:    "thepointsguy.com",
        IpAddress: "162.159.248.114",
    }, 
    &client.Masquerade{
        Domain:    "therakyatpost.com",
        IpAddress: "198.41.190.126",
    }, 
    &client.Masquerade{
        Domain:    "thesportbible.com",
        IpAddress: "190.93.246.96",
    }, 
    &client.Masquerade{
        Domain:    "thevideo.me",
        IpAddress: "162.159.243.240",
    }, 
    &client.Masquerade{
        Domain:    "thisiswhyimbroke.com",
        IpAddress: "162.159.250.214",
    }, 
    &client.Masquerade{
        Domain:    "tickld.com",
        IpAddress: "104.16.26.6",
    }, 
    &client.Masquerade{
        Domain:    "tielabs.com",
        IpAddress: "162.159.244.157",
    }, 
    &client.Masquerade{
        Domain:    "todayifoundout.com",
        IpAddress: "162.159.250.149",
    }, 
    &client.Masquerade{
        Domain:    "torlock.com",
        IpAddress: "198.41.201.25",
    }, 
    &client.Masquerade{
        Domain:    "torrentfreak.com",
        IpAddress: "162.159.246.23",
    }, 
    &client.Masquerade{
        Domain:    "torrentleech.org",
        IpAddress: "108.162.200.95",
    }, 
    &client.Masquerade{
        Domain:    "totalfratmove.com",
        IpAddress: "162.159.249.35",
    }, 
    &client.Masquerade{
        Domain:    "trafficgenesis.com",
        IpAddress: "162.159.241.133",
    }, 
    &client.Masquerade{
        Domain:    "tribalfootball.com",
        IpAddress: "141.101.113.4",
    }, 
    &client.Masquerade{
        Domain:    "tripleclicks.com",
        IpAddress: "141.101.126.214",
    }, 
    &client.Masquerade{
        Domain:    "tructiepbongda.com",
        IpAddress: "198.41.200.45",
    }, 
    &client.Masquerade{
        Domain:    "trueactivist.com",
        IpAddress: "162.159.255.134",
    }, 
    &client.Masquerade{
        Domain:    "tutsplus.com",
        IpAddress: "141.101.112.16",
    }, 
    &client.Masquerade{
        Domain:    "tuvaro.com",
        IpAddress: "162.159.251.141",
    }, 
    &client.Masquerade{
        Domain:    "twentytwowords.com",
        IpAddress: "162.159.245.22",
    }, 
    &client.Masquerade{
        Domain:    "udemy.com",
        IpAddress: "190.93.243.22",
    }, 
    &client.Masquerade{
        Domain:    "ummat.net",
        IpAddress: "141.101.124.43",
    }, 
    &client.Masquerade{
        Domain:    "uniladmag.com",
        IpAddress: "190.93.241.37",
    }, 
    &client.Masquerade{
        Domain:    "unwire.hk",
        IpAddress: "198.41.186.172",
    }, 
    &client.Masquerade{
        Domain:    "updatenowpro.com",
        IpAddress: "162.159.242.60",
    }, 
    &client.Masquerade{
        Domain:    "updatersoft.com",
        IpAddress: "162.159.248.72",
    }, 
    &client.Masquerade{
        Domain:    "uploadboy.com",
        IpAddress: "141.101.125.9",
    }, 
    &client.Masquerade{
        Domain:    "uppit.com",
        IpAddress: "162.159.241.136",
    }, 
    &client.Masquerade{
        Domain:    "uptimerobot.com",
        IpAddress: "108.162.200.240",
    }, 
    &client.Masquerade{
        Domain:    "uptobox.com",
        IpAddress: "190.93.240.95",
    }, 
    &client.Masquerade{
        Domain:    "urbanfonts.com",
        IpAddress: "162.159.240.64",
    }, 
    &client.Masquerade{
        Domain:    "urdupoint.com",
        IpAddress: "162.159.242.213",
    }, 
    &client.Masquerade{
        Domain:    "verseriesynovelas.com",
        IpAddress: "198.41.188.202",
    }, 
    &client.Masquerade{
        Domain:    "vertele.com",
        IpAddress: "162.159.245.94",
    }, 
    &client.Masquerade{
        Domain:    "vetogate.com",
        IpAddress: "190.93.240.58",
    }, 
    &client.Masquerade{
        Domain:    "vidbull.com",
        IpAddress: "162.159.247.224",
    }, 
    &client.Masquerade{
        Domain:    "video.az",
        IpAddress: "162.159.249.246",
    }, 
    &client.Masquerade{
        Domain:    "videomega.tv",
        IpAddress: "162.159.253.156",
    }, 
    &client.Masquerade{
        Domain:    "videostripe.com",
        IpAddress: "198.41.187.157",
    }, 
    &client.Masquerade{
        Domain:    "videoyoum7.com",
        IpAddress: "104.16.25.116",
    }, 
    &client.Masquerade{
        Domain:    "viralistas.com",
        IpAddress: "108.162.206.182",
    }, 
    &client.Masquerade{
        Domain:    "vitorrent.org",
        IpAddress: "162.159.244.211",
    }, 
    &client.Masquerade{
        Domain:    "vladtv.com",
        IpAddress: "162.159.253.31",
    }, 
    &client.Masquerade{
        Domain:    "vodlocker.com",
        IpAddress: "162.159.246.224",
    }, 
    &client.Masquerade{
        Domain:    "vodly.to",
        IpAddress: "190.93.241.35",
    }, 
    &client.Masquerade{
        Domain:    "voetbalzone.nl",
        IpAddress: "198.41.185.200",
    }, 
    &client.Masquerade{
        Domain:    "vr-zone.com",
        IpAddress: "162.159.251.175",
    }, 
    &client.Masquerade{
        Domain:    "watch32.com",
        IpAddress: "162.159.248.45",
    }, 
    &client.Masquerade{
        Domain:    "watchfomny.net",
        IpAddress: "108.162.204.30",
    }, 
    &client.Masquerade{
        Domain:    "watchfreemovies.ch",
        IpAddress: "141.101.123.21",
    }, 
    &client.Masquerade{
        Domain:    "watchseries-online.ch",
        IpAddress: "162.159.250.150",
    }, 
    &client.Masquerade{
        Domain:    "watchserieshd.eu",
        IpAddress: "162.159.252.131",
    }, 
    &client.Masquerade{
        Domain:    "webcamtoy.com",
        IpAddress: "162.159.244.254",
    }, 
    &client.Masquerade{
        Domain:    "webdesignerdepot.com",
        IpAddress: "162.159.240.101",
    }, 
    &client.Masquerade{
        Domain:    "weknowmemes.com",
        IpAddress: "162.159.255.34",
    }, 
    &client.Masquerade{
        Domain:    "what-character-are-you.com",
        IpAddress: "162.159.240.83",
    }, 
    &client.Masquerade{
        Domain:    "what.cd",
        IpAddress: "198.41.189.106",
    }, 
    &client.Masquerade{
        Domain:    "whatculture.com",
        IpAddress: "162.159.240.81",
    }, 
    &client.Masquerade{
        Domain:    "wholehk.com",
        IpAddress: "198.41.204.227",
    }, 
    &client.Masquerade{
        Domain:    "wikiwiki.jp",
        IpAddress: "141.101.123.68",
    }, 
    &client.Masquerade{
        Domain:    "wiziq.com",
        IpAddress: "190.93.244.247",
    }, 
    &client.Masquerade{
        Domain:    "wiziwig.tv",
        IpAddress: "198.41.189.159",
    }, 
    &client.Masquerade{
        Domain:    "wmpoweruser.com",
        IpAddress: "162.159.246.134",
    }, 
    &client.Masquerade{
        Domain:    "woorank.com",
        IpAddress: "190.93.241.25",
    }, 
    &client.Masquerade{
        Domain:    "www.4chan.org",
        IpAddress: "190.93.245.6",
    }, 
    &client.Masquerade{
        Domain:    "www.aciprensa.com",
        IpAddress: "198.41.190.166",
    }, 
    &client.Masquerade{
        Domain:    "www.addtoany.com",
        IpAddress: "141.101.125.160",
    }, 
    &client.Masquerade{
        Domain:    "www.altibbi.com",
        IpAddress: "108.162.204.135",
    }, 
    &client.Masquerade{
        Domain:    "www.alweeam.com.sa",
        IpAddress: "141.101.126.49",
    }, 
    &client.Masquerade{
        Domain:    "www.animenewsnetwork.com",
        IpAddress: "198.41.177.81",
    }, 
    &client.Masquerade{
        Domain:    "www.autostraddle.com",
        IpAddress: "162.159.247.115",
    }, 
    &client.Masquerade{
        Domain:    "www.bien.hu",
        IpAddress: "162.159.244.232",
    }, 
    &client.Masquerade{
        Domain:    "www.binary.com",
        IpAddress: "190.93.240.81",
    }, 
    &client.Masquerade{
        Domain:    "www.bj2.me",
        IpAddress: "190.93.242.108",
    }, 
    &client.Masquerade{
        Domain:    "www.brasil247.com",
        IpAddress: "162.159.251.62",
    }, 
    &client.Masquerade{
        Domain:    "www.bulletproofexec.com",
        IpAddress: "104.20.11.19",
    }, 
    &client.Masquerade{
        Domain:    "www.burnews.com",
        IpAddress: "190.93.241.102",
    }, 
    &client.Masquerade{
        Domain:    "www.cairodar.com",
        IpAddress: "104.16.26.116",
    }, 
    &client.Masquerade{
        Domain:    "www.cairoportal.com",
        IpAddress: "108.162.205.162",
    }, 
    &client.Masquerade{
        Domain:    "www.caracoltv.com",
        IpAddress: "141.101.123.64",
    }, 
    &client.Masquerade{
        Domain:    "www.cbinsights.com",
        IpAddress: "162.159.248.250",
    }, 
    &client.Masquerade{
        Domain:    "www.cbox.ws",
        IpAddress: "162.159.244.249",
    }, 
    &client.Masquerade{
        Domain:    "www.change.org",
        IpAddress: "104.16.4.13",
    }, 
    &client.Masquerade{
        Domain:    "www.clubedohardware.com.br",
        IpAddress: "141.101.127.28",
    }, 
    &client.Masquerade{
        Domain:    "www.connectify.me",
        IpAddress: "141.101.112.191",
    }, 
    &client.Masquerade{
        Domain:    "www.cozi.com",
        IpAddress: "162.159.241.100",
    }, 
    &client.Masquerade{
        Domain:    "www.cpalead.com",
        IpAddress: "198.41.187.57",
    }, 
    &client.Masquerade{
        Domain:    "www.cryptocoinsnews.com",
        IpAddress: "104.20.4.21",
    }, 
    &client.Masquerade{
        Domain:    "www.cssauthor.com",
        IpAddress: "108.162.206.9",
    }, 
    &client.Masquerade{
        Domain:    "www.cyanogenmod.org",
        IpAddress: "162.159.245.104",
    }, 
    &client.Masquerade{
        Domain:    "www.davidicke.com",
        IpAddress: "198.41.185.87",
    }, 
    &client.Masquerade{
        Domain:    "www.dawn.com",
        IpAddress: "162.159.241.171",
    }, 
    &client.Masquerade{
        Domain:    "www.daz3d.com",
        IpAddress: "190.93.242.173",
    }, 
    &client.Masquerade{
        Domain:    "www.diggita.it",
        IpAddress: "162.159.245.162",
    }, 
    &client.Masquerade{
        Domain:    "www.digitalpoint.com",
        IpAddress: "162.159.243.121",
    }, 
    &client.Masquerade{
        Domain:    "www.doomovieonline.com",
        IpAddress: "162.159.244.88",
    }, 
    &client.Masquerade{
        Domain:    "www.ekino.tv",
        IpAddress: "162.159.247.209",
    }, 
    &client.Masquerade{
        Domain:    "www.emailmeform.com",
        IpAddress: "104.16.15.9",
    }, 
    &client.Masquerade{
        Domain:    "www.erepublik.com",
        IpAddress: "108.162.205.105",
    }, 
    &client.Masquerade{
        Domain:    "www.ezilon.com",
        IpAddress: "190.93.240.65",
    }, 
    &client.Masquerade{
        Domain:    "www.fatosdesconhecidos.com.br",
        IpAddress: "190.93.250.184",
    }, 
    &client.Masquerade{
        Domain:    "www.filmpertutti.eu",
        IpAddress: "162.159.245.197",
    }, 
    &client.Masquerade{
        Domain:    "www.firedrive.com",
        IpAddress: "190.93.245.69",
    }, 
    &client.Masquerade{
        Domain:    "www.foodpanda.in",
        IpAddress: "104.16.1.10",
    }, 
    &client.Masquerade{
        Domain:    "www.forosdelweb.com",
        IpAddress: "141.101.121.35",
    }, 
    &client.Masquerade{
        Domain:    "www.forosperu.net",
        IpAddress: "198.41.190.72",
    }, 
    &client.Masquerade{
        Domain:    "www.freeonlinegames.com",
        IpAddress: "141.101.123.38",
    }, 
    &client.Masquerade{
        Domain:    "www.frmtr.com",
        IpAddress: "162.159.242.133",
    }, 
    &client.Masquerade{
        Domain:    "www.furaffinity.net",
        IpAddress: "141.101.124.102",
    }, 
    &client.Masquerade{
        Domain:    "www.geenstijl.nl",
        IpAddress: "162.159.252.153",
    }, 
    &client.Masquerade{
        Domain:    "www.giltcity.com",
        IpAddress: "141.101.114.238",
    }, 
    &client.Masquerade{
        Domain:    "www.globallshare.com",
        IpAddress: "141.101.127.226",
    }, 
    &client.Masquerade{
        Domain:    "www.grandbux.net",
        IpAddress: "141.101.127.161",
    }, 
    &client.Masquerade{
        Domain:    "www.gulli.com",
        IpAddress: "141.101.113.28",
    }, 
    &client.Masquerade{
        Domain:    "www.hespress.com",
        IpAddress: "162.159.255.97",
    }, 
    &client.Masquerade{
        Domain:    "www.iab.net",
        IpAddress: "141.101.112.75",
    }, 
    &client.Masquerade{
        Domain:    "www.india-forums.com",
        IpAddress: "108.162.200.45",
    }, 
    &client.Masquerade{
        Domain:    "www.infusionsoft.com",
        IpAddress: "198.41.247.138",
    }, 
    &client.Masquerade{
        Domain:    "www.iol.co.za",
        IpAddress: "104.20.29.75",
    }, 
    &client.Masquerade{
        Domain:    "www.jobscore.com",
        IpAddress: "141.101.112.224",
    }, 
    &client.Masquerade{
        Domain:    "www.joe.ie",
        IpAddress: "108.162.202.217",
    }, 
    &client.Masquerade{
        Domain:    "www.jonloomer.com",
        IpAddress: "141.101.126.76",
    }, 
    &client.Masquerade{
        Domain:    "www.joomshaper.com",
        IpAddress: "108.162.205.40",
    }, 
    &client.Masquerade{
        Domain:    "www.jotform.com",
        IpAddress: "141.101.121.40",
    }, 
    &client.Masquerade{
        Domain:    "www.jumia.com.eg",
        IpAddress: "198.41.191.223",
    }, 
    &client.Masquerade{
        Domain:    "www.knownhost.com",
        IpAddress: "162.159.242.146",
    }, 
    &client.Masquerade{
        Domain:    "www.kora.com",
        IpAddress: "104.20.3.49",
    }, 
    &client.Masquerade{
        Domain:    "www.lebanese-forces.com",
        IpAddress: "141.101.121.66",
    }, 
    &client.Masquerade{
        Domain:    "www.life.com.tw",
        IpAddress: "141.101.123.19",
    }, 
    &client.Masquerade{
        Domain:    "www.like4like.org",
        IpAddress: "190.93.240.75",
    }, 
    &client.Masquerade{
        Domain:    "www.lostfilm.tv",
        IpAddress: "5.199.162.26",
    }, 
    &client.Masquerade{
        Domain:    "www.maduradas.com",
        IpAddress: "162.159.242.224",
    }, 
    &client.Masquerade{
        Domain:    "www.mafa.com",
        IpAddress: "162.159.254.249",
    }, 
    &client.Masquerade{
        Domain:    "www.maxmind.com",
        IpAddress: "141.101.114.190",
    }, 
    &client.Masquerade{
        Domain:    "www.mindtools.com",
        IpAddress: "162.159.254.124",
    }, 
    &client.Masquerade{
        Domain:    "www.mkyong.com",
        IpAddress: "108.162.203.6",
    }, 
    &client.Masquerade{
        Domain:    "www.mobofree.com",
        IpAddress: "162.159.252.219",
    }, 
    &client.Masquerade{
        Domain:    "www.modernghana.com",
        IpAddress: "162.159.252.105",
    }, 
    &client.Masquerade{
        Domain:    "www.mp3xd.com",
        IpAddress: "162.159.251.214",
    }, 
    &client.Masquerade{
        Domain:    "www.myitworks.com",
        IpAddress: "162.159.249.96",
    }, 
    &client.Masquerade{
        Domain:    "www.myvidster.com",
        IpAddress: "198.41.205.6",
    }, 
    &client.Masquerade{
        Domain:    "www.namepros.com",
        IpAddress: "198.41.249.130",
    }, 
    &client.Masquerade{
        Domain:    "www.naointendo.com.br",
        IpAddress: "162.159.243.65",
    }, 
    &client.Masquerade{
        Domain:    "www.newgrounds.com",
        IpAddress: "198.41.187.234",
    }, 
    &client.Masquerade{
        Domain:    "www.nomadicmatt.com",
        IpAddress: "162.159.247.103",
    }, 
    &client.Masquerade{
        Domain:    "www.nthwall.com",
        IpAddress: "104.20.2.28",
    }, 
    &client.Masquerade{
        Domain:    "www.oboom.com",
        IpAddress: "104.20.4.7",
    }, 
    &client.Masquerade{
        Domain:    "www.ofreegames.com",
        IpAddress: "162.159.253.249",
    }, 
    &client.Masquerade{
        Domain:    "www.okcupid.com",
        IpAddress: "198.41.209.132",
    }, 
    &client.Masquerade{
        Domain:    "www.pccomponentes.com",
        IpAddress: "162.159.254.66",
    }, 
    &client.Masquerade{
        Domain:    "www.pdftoword.com",
        IpAddress: "162.159.242.180",
    }, 
    &client.Masquerade{
        Domain:    "www.perrymarshall.com",
        IpAddress: "162.159.250.212",
    }, 
    &client.Masquerade{
        Domain:    "www.plugrush.com",
        IpAddress: "162.159.252.157",
    }, 
    &client.Masquerade{
        Domain:    "www.portalnet.cl",
        IpAddress: "162.159.246.34",
    }, 
    &client.Masquerade{
        Domain:    "www.powned.tv",
        IpAddress: "162.159.244.144",
    }, 
    &client.Masquerade{
        Domain:    "www.preciolandia.com",
        IpAddress: "162.159.243.104",
    }, 
    &client.Masquerade{
        Domain:    "www.primewire.ag",
        IpAddress: "104.20.31.76",
    }, 
    &client.Masquerade{
        Domain:    "www.problogger.net",
        IpAddress: "162.159.249.46",
    }, 
    &client.Masquerade{
        Domain:    "www.producthunt.com",
        IpAddress: "162.159.251.254",
    }, 
    &client.Masquerade{
        Domain:    "www.pushbullet.com",
        IpAddress: "162.159.242.182",
    }, 
    &client.Masquerade{
        Domain:    "www.quadratin.com.mx",
        IpAddress: "162.159.252.45",
    }, 
    &client.Masquerade{
        Domain:    "www.racing-games.com",
        IpAddress: "162.159.252.249",
    }, 
    &client.Masquerade{
        Domain:    "www.rapidvideo.org",
        IpAddress: "162.159.240.68",
    }, 
    &client.Masquerade{
        Domain:    "www.ratemds.com",
        IpAddress: "104.20.20.13",
    }, 
    &client.Masquerade{
        Domain:    "www.renuevodeplenitud.com",
        IpAddress: "162.159.240.79",
    }, 
    &client.Masquerade{
        Domain:    "www.rome2rio.com",
        IpAddress: "108.162.205.115",
    }, 
    &client.Masquerade{
        Domain:    "www.sage.com",
        IpAddress: "104.16.1.19",
    }, 
    &client.Masquerade{
        Domain:    "www.shortlist.com",
        IpAddress: "141.101.123.31",
    }, 
    &client.Masquerade{
        Domain:    "www.sockshare.com",
        IpAddress: "190.93.246.172",
    }, 
    &client.Masquerade{
        Domain:    "www.somethingawful.com",
        IpAddress: "198.41.185.131",
    }, 
    &client.Masquerade{
        Domain:    "www.songspk.name",
        IpAddress: "108.162.201.183",
    }, 
    &client.Masquerade{
        Domain:    "www.ssense.com",
        IpAddress: "104.20.13.4",
    }, 
    &client.Masquerade{
        Domain:    "www.stoiximan.gr",
        IpAddress: "190.93.241.131",
    }, 
    &client.Masquerade{
        Domain:    "www.sundayworld.com",
        IpAddress: "198.41.186.49",
    }, 
    &client.Masquerade{
        Domain:    "www.surveygizmo.com",
        IpAddress: "104.16.18.4",
    }, 
    &client.Masquerade{
        Domain:    "www.sweetfunnycool.com",
        IpAddress: "198.41.249.82",
    }, 
    &client.Masquerade{
        Domain:    "www.techdirt.com",
        IpAddress: "162.159.243.199",
    }, 
    &client.Masquerade{
        Domain:    "www.teefury.com",
        IpAddress: "190.93.240.12",
    }, 
    &client.Masquerade{
        Domain:    "www.thedarewall.com",
        IpAddress: "198.41.191.162",
    }, 
    &client.Masquerade{
        Domain:    "www.thegrommet.com",
        IpAddress: "198.41.188.212",
    }, 
    &client.Masquerade{
        Domain:    "www.theladbible.com",
        IpAddress: "198.41.215.4",
    }, 
    &client.Masquerade{
        Domain:    "www.thenewslens.com",
        IpAddress: "108.162.204.219",
    }, 
    &client.Masquerade{
        Domain:    "www.thingiverse.com",
        IpAddress: "162.159.251.32",
    }, 
    &client.Masquerade{
        Domain:    "www.thisiscolossal.com",
        IpAddress: "108.162.203.135",
    }, 
    &client.Masquerade{
        Domain:    "www.torrentfunk.com",
        IpAddress: "198.41.201.42",
    }, 
    &client.Masquerade{
        Domain:    "www.traidnt.net",
        IpAddress: "141.101.112.65",
    }, 
    &client.Masquerade{
        Domain:    "www.tunisia-sat.com",
        IpAddress: "162.159.243.166",
    }, 
    &client.Masquerade{
        Domain:    "www.tvrage.com",
        IpAddress: "162.159.242.117",
    }, 
    &client.Masquerade{
        Domain:    "www.twickerz.com",
        IpAddress: "198.41.249.234",
    }, 
    &client.Masquerade{
        Domain:    "www.vavel.com",
        IpAddress: "190.93.241.103",
    }, 
    &client.Masquerade{
        Domain:    "www.wayn.com",
        IpAddress: "141.101.112.110",
    }, 
    &client.Masquerade{
        Domain:    "www.webmastersitesi.com",
        IpAddress: "141.101.120.109",
    }, 
    &client.Masquerade{
        Domain:    "www.whatismyip.com",
        IpAddress: "141.101.120.15",
    }, 
    &client.Masquerade{
        Domain:    "www.whmcs.com",
        IpAddress: "190.93.241.179",
    }, 
    &client.Masquerade{
        Domain:    "www.wphub.com",
        IpAddress: "162.159.242.55",
    }, 
    &client.Masquerade{
        Domain:    "www.yokboylebirsey.com.tr",
        IpAddress: "162.159.244.252",
    }, 
    &client.Masquerade{
        Domain:    "www.yougetsignal.com",
        IpAddress: "141.101.127.83",
    }, 
    &client.Masquerade{
        Domain:    "www.zaman.com.tr",
        IpAddress: "141.101.114.170",
    }, 
    &client.Masquerade{
        Domain:    "www.zopim.com",
        IpAddress: "190.93.240.200",
    }, 
    &client.Masquerade{
        Domain:    "www.zumba.com",
        IpAddress: "190.93.246.77",
    }, 
    &client.Masquerade{
        Domain:    "x-kom.pl",
        IpAddress: "104.20.29.24",
    }, 
    &client.Masquerade{
        Domain:    "xat.com",
        IpAddress: "141.101.123.82",
    }, 
    &client.Masquerade{
        Domain:    "xendan.org",
        IpAddress: "190.93.243.133",
    }, 
    &client.Masquerade{
        Domain:    "yell.ru",
        IpAddress: "190.93.254.197",
    }, 
    &client.Masquerade{
        Domain:    "yifysubtitles.com",
        IpAddress: "141.101.127.79",
    }, 
    &client.Masquerade{
        Domain:    "youm7.com",
        IpAddress: "104.16.18.116",
    }, 
    &client.Masquerade{
        Domain:    "yourbittorrent.com",
        IpAddress: "198.41.202.40",
    }, 
    &client.Masquerade{
        Domain:    "yourdailyscoop.com",
        IpAddress: "162.159.248.210",
    }, 
    &client.Masquerade{
        Domain:    "yourvideofile.org",
        IpAddress: "198.41.249.128",
    }, 
    &client.Masquerade{
        Domain:    "yyv.co",
        IpAddress: "141.101.112.66",
    }, 
    &client.Masquerade{
        Domain:    "z6.com",
        IpAddress: "162.159.248.121",
    }, 
    &client.Masquerade{
        Domain:    "zemtv.com",
        IpAddress: "141.101.124.11",
    }, 
    &client.Masquerade{
        Domain:    "zennolab.com",
        IpAddress: "162.159.240.26",
    }, 
    &client.Masquerade{
        Domain:    "zentrum-der-gesundheit.de",
        IpAddress: "141.101.112.102",
    }, 
    &client.Masquerade{
        Domain:    "zerozero.pt",
        IpAddress: "198.41.185.108",
    }, 
    &client.Masquerade{
        Domain:    "zurb.com",
        IpAddress: "104.20.4.2",
    }, 
    &client.Masquerade{
        Domain:    "zwaar.net",
        IpAddress: "162.159.248.231",
    }, 
}