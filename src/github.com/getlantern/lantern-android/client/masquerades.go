package client

import "github.com/getlantern/fronted"

var defaultTrustedCAs = []*ca{
	&ca{
		CommonName: "GlobalSign Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n",
	},
	&ca{
		CommonName: "AddTrust External CA Root",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIENjCCAx6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBvMQswCQYDVQQGEwJTRTEU\nMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFs\nIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290\nMB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowbzELMAkGA1UEBhMCU0Ux\nFDASBgNVBAoTC0FkZFRydXN0IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5h\nbCBUVFAgTmV0d29yazEiMCAGA1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9v\ndDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALf3GjPm8gAELTngTlvt\nH7xsD821+iO2zt6bETOXpClMfZOfvUq8k+0DGuOPz+VtUFrWlymUWoCwSXrbLpX9\nuMq/NzgtHj6RQa1wVsfwTz/oMp50ysiQVOnGXw94nZpAPA6sYapeFI+eh6FqUNzX\nmk6vBbOmcZSccbNQYArHE504B4YCqOmoaSYYkKtMsE8jqzpPhNjfzp/haW+710LX\na0Tkx63ubUFfclpxCDezeWWkWaCUN/cALw3CknLa0Dhy2xSoRcRdKn23tNbE7qzN\nE0S3ySvdQwAl+mG5aWpYIxG3pzOPVnVZ9c0p10a3CitlttNCbxWyuHv77+ldU9U0\nWicCAwEAAaOB3DCB2TAdBgNVHQ4EFgQUrb2YejS0Jvf6xCZU7wO94CTLVBowCwYD\nVR0PBAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wgZkGA1UdIwSBkTCBjoAUrb2YejS0\nJvf6xCZU7wO94CTLVBqhc6RxMG8xCzAJBgNVBAYTAlNFMRQwEgYDVQQKEwtBZGRU\ncnVzdCBBQjEmMCQGA1UECxMdQWRkVHJ1c3QgRXh0ZXJuYWwgVFRQIE5ldHdvcmsx\nIjAgBgNVBAMTGUFkZFRydXN0IEV4dGVybmFsIENBIFJvb3SCAQEwDQYJKoZIhvcN\nAQEFBQADggEBALCb4IUlwtYj4g+WBpKdQZic2YR5gdkeWxQHIzZlj7DYd7usQWxH\nYINRsPkyPef89iYTx4AWpb9a/IfPeHmJIZriTAcKhjW88t5RxNKWt9x+Tu5w/Rw5\n6wwCURQtjr0W4MHfRnXnJK3s9EK0hZNwEGe6nQY1ShjTK3rMUUKhemPR5ruhxSvC\nNr4TDea9Y355e6cJDUCrat2PisP29owaQgVR1EX1n6diIWgVIEM8med8vSTYqZEX\nc4g/VhsxOBi0cQ+azcgOno4uG+GMmIPLHzHxREzGBHNJdmAPx/i9F4BrLunMTA5a\nmnkPIAou1Z5jJh5VkpTYghdae9C8x49OhgQ=\n-----END CERTIFICATE-----\n",
	},
	&ca{
		CommonName: "GeoTrust Global CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT\nMRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i\nYWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG\nEwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg\nR2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9\n9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq\nfnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv\niS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU\n1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+\nbw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW\nMPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA\nephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l\nuMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn\nZ57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS\ntQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF\nPseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un\nhw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV\n5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==\n-----END CERTIFICATE-----\n",
	},
	&ca{
		CommonName: "Go Daddy Root Certificate Authority - G2",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIBADANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMx\nEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoT\nEUdvRGFkZHkuY29tLCBJbmMuMTEwLwYDVQQDEyhHbyBEYWRkeSBSb290IENlcnRp\nZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIz\nNTk1OVowgYMxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQH\nEwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5LmNvbSwgSW5jLjExMC8GA1UE\nAxMoR28gRGFkZHkgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9xYgjx+lk09xvJGKP3gElY6SKD\nE6bFIEMBO4Tx5oVJnyfq9oQbTqC023CYxzIBsQU+B07u9PpPL1kwIuerGVZr4oAH\n/PMWdYA5UXvl+TW2dE6pjYIT5LY/qQOD+qK+ihVqf94Lw7YZFAXK6sOoBJQ7Rnwy\nDfMAZiLIjWltNowRGLfTshxgtDj6AozO091GB94KPutdfMh8+7ArU6SSYmlRJQVh\nGkSBjCypQ5Yj36w6gZoOKcUcqeldHraenjAKOc7xiID7S13MMuyFYkMlNAJWJwGR\ntDtwKj9useiciAF9n9T521NtYJ2/LOdYq7hfRvzOxBsDPAnrSTFcaUaz4EcCAwEA\nAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE\nFDqahQcQZyi27/a9BUFuIMGU2g/eMA0GCSqGSIb3DQEBCwUAA4IBAQCZ21151fmX\nWWcDYfF+OwYxdS2hII5PZYe096acvNjpL9DbWu7PdIxztDhC2gV7+AJ1uP2lsdeu\n9tfeE8tTEH6KRtGX+rcuKxGrkLAngPnon1rpN5+r5N9ss4UXnT3ZJE95kTXWXwTr\ngIOrmgIttRD02JDHBHNA7XIloKmf7J6raBKZV8aPEjoJpL1E/QYVN8Gb5DKj7Tjo\n2GTzLH4U/ALqn83/B2gX2yKQOC16jdFU8WnjXzPKej17CuPKf1855eJ1usV2GDPO\nLPAvTK33sefOT6jEm0pUBsV/fdUID+Ic/n4XuKxe9tQWskMJDE32p2u0mYRlynqI\n4uJEvlz36hz1\n-----END CERTIFICATE-----\n",
	},
}

var cloudflareMasquerades = []*fronted.Masquerade{
	&fronted.Masquerade{
		Domain:    "10minutemail.com",
		IpAddress: "162.159.250.16",
	},
	&fronted.Masquerade{
		Domain:    "1news.az",
		IpAddress: "162.159.241.30",
	},
	&fronted.Masquerade{
		Domain:    "2ch.hk",
		IpAddress: "104.20.22.31",
	},
	&fronted.Masquerade{
		Domain:    "a2hosting.com",
		IpAddress: "198.41.184.200",
	},
	&fronted.Masquerade{
		Domain:    "abs-cbnnews.com",
		IpAddress: "104.16.14.162",
	},
	&fronted.Masquerade{
		Domain:    "addmefast.com",
		IpAddress: "198.41.190.157",
	},
	&fronted.Masquerade{
		Domain:    "adf.ly",
		IpAddress: "104.20.1.4",
	},
	&fronted.Masquerade{
		Domain:    "adfoc.us",
		IpAddress: "162.159.253.17",
	},
	&fronted.Masquerade{
		Domain:    "adlure.net",
		IpAddress: "141.101.113.94",
	},
	&fronted.Masquerade{
		Domain:    "ads.id",
		IpAddress: "162.159.251.152",
	},
	&fronted.Masquerade{
		Domain:    "affiliatetechnology.com",
		IpAddress: "198.41.184.52",
	},
	&fronted.Masquerade{
		Domain:    "agentlk.com",
		IpAddress: "190.93.240.73",
	},
	&fronted.Masquerade{
		Domain:    "aitnews.com",
		IpAddress: "190.93.253.92",
	},
	&fronted.Masquerade{
		Domain:    "al-akhbar.com",
		IpAddress: "162.159.244.97",
	},
	&fronted.Masquerade{
		Domain:    "allanalpass.com",
		IpAddress: "162.159.245.34",
	},
	&fronted.Masquerade{
		Domain:    "allbusiness.com",
		IpAddress: "162.159.246.140",
	},
	&fronted.Masquerade{
		Domain:    "almasryalyoum.com",
		IpAddress: "141.101.113.103",
	},
	&fronted.Masquerade{
		Domain:    "alrakoba.net",
		IpAddress: "198.41.190.72",
	},
	&fronted.Masquerade{
		Domain:    "alwatanvoice.com",
		IpAddress: "162.159.255.143",
	},
	&fronted.Masquerade{
		Domain:    "amazinglytimedphotos.com",
		IpAddress: "198.41.185.180",
	},
	&fronted.Masquerade{
		Domain:    "amino.dk",
		IpAddress: "198.41.184.122",
	},
	&fronted.Masquerade{
		Domain:    "anakbnet.com",
		IpAddress: "162.159.251.168",
	},
	&fronted.Masquerade{
		Domain:    "anazahra.com",
		IpAddress: "162.159.254.7",
	},
	&fronted.Masquerade{
		Domain:    "any.gs",
		IpAddress: "162.159.240.58",
	},
	&fronted.Masquerade{
		Domain:    "aporrea.org",
		IpAddress: "108.162.202.29",
	},
	&fronted.Masquerade{
		Domain:    "appstorm.net",
		IpAddress: "162.159.243.165",
	},
	&fronted.Masquerade{
		Domain:    "aqarcity.com",
		IpAddress: "198.41.184.74",
	},
	&fronted.Masquerade{
		Domain:    "aqarmap.com",
		IpAddress: "162.159.249.95",
	},
	&fronted.Masquerade{
		Domain:    "arabnews.com",
		IpAddress: "108.162.204.20",
	},
	&fronted.Masquerade{
		Domain:    "arabseed.com",
		IpAddress: "198.41.188.132",
	},
	&fronted.Masquerade{
		Domain:    "armorgames.com",
		IpAddress: "104.20.4.17",
	},
	&fronted.Masquerade{
		Domain:    "asianbookie.com",
		IpAddress: "162.159.249.133",
	},
	&fronted.Masquerade{
		Domain:    "asianwiki.com",
		IpAddress: "162.159.246.82",
	},
	&fronted.Masquerade{
		Domain:    "authorstream.com",
		IpAddress: "190.93.246.194",
	},
	&fronted.Masquerade{
		Domain:    "avaz.ba",
		IpAddress: "162.159.244.253",
	},
	&fronted.Masquerade{
		Domain:    "avpixlat.info",
		IpAddress: "190.93.242.137",
	},
	&fronted.Masquerade{
		Domain:    "axsam.az",
		IpAddress: "162.159.243.133",
	},
	&fronted.Masquerade{
		Domain:    "azvision.az",
		IpAddress: "162.159.243.148",
	},
	&fronted.Masquerade{
		Domain:    "b1.org",
		IpAddress: "162.159.243.39",
	},
	&fronted.Masquerade{
		Domain:    "babyou.com",
		IpAddress: "108.162.206.67",
	},
	&fronted.Masquerade{
		Domain:    "banahosting.com",
		IpAddress: "162.159.245.11",
	},
	&fronted.Masquerade{
		Domain:    "baykoreans.net",
		IpAddress: "190.93.240.11",
	},
	&fronted.Masquerade{
		Domain:    "bezuzyteczna.pl",
		IpAddress: "198.41.176.34",
	},
	&fronted.Masquerade{
		Domain:    "bikroy.com",
		IpAddress: "162.159.253.158",
	},
	&fronted.Masquerade{
		Domain:    "bittrex.com",
		IpAddress: "162.159.246.225",
	},
	&fronted.Masquerade{
		Domain:    "bizimyol.info",
		IpAddress: "190.93.240.19",
	},
	&fronted.Masquerade{
		Domain:    "blabbermouth.net",
		IpAddress: "162.159.247.184",
	},
	&fronted.Masquerade{
		Domain:    "bleepingcomputer.com",
		IpAddress: "141.101.112.117",
	},
	&fronted.Masquerade{
		Domain:    "bloody-disgusting.com",
		IpAddress: "162.159.249.220",
	},
	&fronted.Masquerade{
		Domain:    "brainstorm9.com.br",
		IpAddress: "162.159.250.96",
	},
	&fronted.Masquerade{
		Domain:    "btalah.com",
		IpAddress: "162.159.247.103",
	},
	&fronted.Masquerade{
		Domain:    "btc-e.com",
		IpAddress: "141.101.121.193",
	},
	&fronted.Masquerade{
		Domain:    "bubblews.com",
		IpAddress: "190.93.241.103",
	},
	&fronted.Masquerade{
		Domain:    "bugmenot.com",
		IpAddress: "162.159.248.51",
	},
	&fronted.Masquerade{
		Domain:    "bukkit.org",
		IpAddress: "190.93.246.100",
	},
	&fronted.Masquerade{
		Domain:    "businessinsider.com.au",
		IpAddress: "190.93.245.134",
	},
	&fronted.Masquerade{
		Domain:    "buzznews.asia",
		IpAddress: "198.41.186.124",
	},
	&fronted.Masquerade{
		Domain:    "buzzsumo.com",
		IpAddress: "108.162.202.208",
	},
	&fronted.Masquerade{
		Domain:    "cairokora.com",
		IpAddress: "104.16.31.116",
	},
	&fronted.Masquerade{
		Domain:    "canva.com",
		IpAddress: "162.159.245.88",
	},
	&fronted.Masquerade{
		Domain:    "careers360.com",
		IpAddress: "162.159.242.132",
	},
	&fronted.Masquerade{
		Domain:    "catracalivre.com.br",
		IpAddress: "198.41.247.124",
	},
	&fronted.Masquerade{
		Domain:    "cdn-cachefront.net",
		IpAddress: "162.159.244.124",
	},
	&fronted.Masquerade{
		Domain:    "censor.net.ua",
		IpAddress: "198.41.188.113",
	},
	&fronted.Masquerade{
		Domain:    "chinabuye.com",
		IpAddress: "198.41.185.203",
	},
	&fronted.Masquerade{
		Domain:    "cihan.com.tr",
		IpAddress: "104.16.3.7",
	},
	&fronted.Masquerade{
		Domain:    "cinetux.org",
		IpAddress: "162.159.251.123",
	},
	&fronted.Masquerade{
		Domain:    "cleanfiles.net",
		IpAddress: "190.93.243.46",
	},
	&fronted.Masquerade{
		Domain:    "clixsense.com",
		IpAddress: "198.41.188.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudify.cc",
		IpAddress: "162.159.254.62",
	},
	&fronted.Masquerade{
		Domain:    "coinmarketcap.com",
		IpAddress: "162.159.240.183",
	},
	&fronted.Masquerade{
		Domain:    "col3negoriginal.lk",
		IpAddress: "190.93.242.9",
	},
	&fronted.Masquerade{
		Domain:    "collective-evolution.com",
		IpAddress: "198.41.189.248",
	},
	&fronted.Masquerade{
		Domain:    "com-2014.org",
		IpAddress: "162.159.240.96",
	},
	&fronted.Masquerade{
		Domain:    "conservativetribune.com",
		IpAddress: "162.159.242.147",
	},
	&fronted.Masquerade{
		Domain:    "conversionxl.com",
		IpAddress: "162.159.242.170",
	},
	&fronted.Masquerade{
		Domain:    "convinceandconvert.com",
		IpAddress: "190.93.251.116",
	},
	&fronted.Masquerade{
		Domain:    "copacet.com",
		IpAddress: "108.162.202.100",
	},
	&fronted.Masquerade{
		Domain:    "cpagrip.com",
		IpAddress: "198.41.186.139",
	},
	&fronted.Masquerade{
		Domain:    "cpasbien.pe",
		IpAddress: "104.16.15.124",
	},
	&fronted.Masquerade{
		Domain:    "cssmenumaker.com",
		IpAddress: "162.159.250.136",
	},
	&fronted.Masquerade{
		Domain:    "cuevana2.tv",
		IpAddress: "162.159.242.105",
	},
	&fronted.Masquerade{
		Domain:    "culturacolectiva.com",
		IpAddress: "162.159.240.99",
	},
	&fronted.Masquerade{
		Domain:    "curse.com",
		IpAddress: "190.93.244.102",
	},
	&fronted.Masquerade{
		Domain:    "cursecdn.com",
		IpAddress: "198.41.209.101",
	},
	&fronted.Masquerade{
		Domain:    "dangerousminds.net",
		IpAddress: "108.162.200.38",
	},
	&fronted.Masquerade{
		Domain:    "datatables.net",
		IpAddress: "162.159.244.98",
	},
	&fronted.Masquerade{
		Domain:    "dealcatcher.com",
		IpAddress: "162.159.249.16",
	},
	&fronted.Masquerade{
		Domain:    "delivery-club.ru",
		IpAddress: "104.16.24.8",
	},
	&fronted.Masquerade{
		Domain:    "demotywatory.pl",
		IpAddress: "95.211.149.169",
	},
	&fronted.Masquerade{
		Domain:    "deperu.com",
		IpAddress: "198.41.249.212",
	},
	&fronted.Masquerade{
		Domain:    "designboom.com",
		IpAddress: "162.159.245.146",
	},
	&fronted.Masquerade{
		Domain:    "deutsche-wirtschafts-nachrichten.de",
		IpAddress: "198.41.185.52",
	},
	&fronted.Masquerade{
		Domain:    "diablofans.com",
		IpAddress: "198.41.208.103",
	},
	&fronted.Masquerade{
		Domain:    "digital-photography-school.com",
		IpAddress: "162.159.249.46",
	},
	&fronted.Masquerade{
		Domain:    "dnevnik.hr",
		IpAddress: "190.93.240.21",
	},
	&fronted.Masquerade{
		Domain:    "download-genius.com",
		IpAddress: "162.159.240.171",
	},
	&fronted.Masquerade{
		Domain:    "downloadming.nu",
		IpAddress: "198.41.188.76",
	},
	&fronted.Masquerade{
		Domain:    "dpstream.net",
		IpAddress: "198.41.189.151",
	},
	&fronted.Masquerade{
		Domain:    "drp.su",
		IpAddress: "162.159.244.17",
	},
	&fronted.Masquerade{
		Domain:    "dumpaday.com",
		IpAddress: "162.159.241.119",
	},
	&fronted.Masquerade{
		Domain:    "e-cigarette-forum.com",
		IpAddress: "162.159.255.238",
	},
	&fronted.Masquerade{
		Domain:    "e-monsite.com",
		IpAddress: "141.101.120.123",
	},
	&fronted.Masquerade{
		Domain:    "e-radio.gr",
		IpAddress: "198.41.181.19",
	},
	&fronted.Masquerade{
		Domain:    "eclypsia.com",
		IpAddress: "190.93.242.97",
	},
	&fronted.Masquerade{
		Domain:    "ecuavisa.com",
		IpAddress: "141.101.113.36",
	},
	&fronted.Masquerade{
		Domain:    "edublogs.org",
		IpAddress: "104.16.0.23",
	},
	&fronted.Masquerade{
		Domain:    "egaliteetreconciliation.fr",
		IpAddress: "190.93.242.80",
	},
	&fronted.Masquerade{
		Domain:    "egyup.com",
		IpAddress: "108.162.201.33",
	},
	&fronted.Masquerade{
		Domain:    "eharmony.com",
		IpAddress: "199.83.133.3",
	},
	&fronted.Masquerade{
		Domain:    "einthusan.com",
		IpAddress: "198.41.184.127",
	},
	&fronted.Masquerade{
		Domain:    "elakiri.com",
		IpAddress: "162.159.250.73",
	},
	&fronted.Masquerade{
		Domain:    "elhacker.net",
		IpAddress: "108.162.206.73",
	},
	&fronted.Masquerade{
		Domain:    "elwatannews.com",
		IpAddress: "104.20.14.106",
	},
	&fronted.Masquerade{
		Domain:    "en.bitcoin.it",
		IpAddress: "162.159.245.241",
	},
	&fronted.Masquerade{
		Domain:    "eslamoda.com",
		IpAddress: "162.159.254.119",
	},
	&fronted.Masquerade{
		Domain:    "esteghlali.com",
		IpAddress: "108.162.205.71",
	},
	&fronted.Masquerade{
		Domain:    "etorrent.co.kr",
		IpAddress: "198.41.190.119",
	},
	&fronted.Masquerade{
		Domain:    "eurostreaming.tv",
		IpAddress: "162.159.242.231",
	},
	&fronted.Masquerade{
		Domain:    "euw.leagueoflegends.com",
		IpAddress: "104.16.30.33",
	},
	&fronted.Masquerade{
		Domain:    "evozi.com",
		IpAddress: "198.41.202.14",
	},
	&fronted.Masquerade{
		Domain:    "explosm.net",
		IpAddress: "108.162.203.152",
	},
	&fronted.Masquerade{
		Domain:    "expressleech.com",
		IpAddress: "108.162.202.115",
	},
	&fronted.Masquerade{
		Domain:    "extratorrent.cc",
		IpAddress: "162.159.255.81",
	},
	&fronted.Masquerade{
		Domain:    "faithtap.com",
		IpAddress: "198.41.185.57",
	},
	&fronted.Masquerade{
		Domain:    "famousbirthdays.com",
		IpAddress: "141.101.114.80",
	},
	&fronted.Masquerade{
		Domain:    "fasttech.com",
		IpAddress: "141.101.112.98",
	},
	&fronted.Masquerade{
		Domain:    "feedly.com",
		IpAddress: "162.159.252.4",
	},
	&fronted.Masquerade{
		Domain:    "filesfetcher.com",
		IpAddress: "198.41.185.168",
	},
	&fronted.Masquerade{
		Domain:    "filmesonlinegratis.net",
		IpAddress: "190.93.243.37",
	},
	&fronted.Masquerade{
		Domain:    "fiverr.com",
		IpAddress: "192.33.31.61",
	},
	&fronted.Masquerade{
		Domain:    "flashgames.it",
		IpAddress: "141.101.120.118",
	},
	&fronted.Masquerade{
		Domain:    "follow.net",
		IpAddress: "198.41.189.9",
	},
	&fronted.Masquerade{
		Domain:    "food52.com",
		IpAddress: "104.20.1.127",
	},
	&fronted.Masquerade{
		Domain:    "footballchannel.jp",
		IpAddress: "162.159.247.145",
	},
	&fronted.Masquerade{
		Domain:    "forbes.com.mx",
		IpAddress: "162.159.249.40",
	},
	&fronted.Masquerade{
		Domain:    "forexpeacearmy.com",
		IpAddress: "190.93.242.28",
	},
	&fronted.Masquerade{
		Domain:    "forgifs.com",
		IpAddress: "162.159.251.66",
	},
	&fronted.Masquerade{
		Domain:    "freebitco.in",
		IpAddress: "162.159.244.200",
	},
	&fronted.Masquerade{
		Domain:    "freedoge.co.in",
		IpAddress: "141.101.127.23",
	},
	&fronted.Masquerade{
		Domain:    "freemalaysiatoday.com",
		IpAddress: "162.159.248.43",
	},
	&fronted.Masquerade{
		Domain:    "freenode.net",
		IpAddress: "162.159.249.27",
	},
	&fronted.Masquerade{
		Domain:    "frontpage.fok.nl",
		IpAddress: "108.162.200.126",
	},
	&fronted.Masquerade{
		Domain:    "fshare.vn",
		IpAddress: "118.69.164.133",
	},
	&fronted.Masquerade{
		Domain:    "fsplay.net",
		IpAddress: "198.41.189.238",
	},
	&fronted.Masquerade{
		Domain:    "full-stream.net",
		IpAddress: "198.41.202.82",
	},
	&fronted.Masquerade{
		Domain:    "fun698.com",
		IpAddress: "198.41.206.118",
	},
	&fronted.Masquerade{
		Domain:    "funnymama.com",
		IpAddress: "198.41.249.64",
	},
	&fronted.Masquerade{
		Domain:    "futhead.com",
		IpAddress: "190.93.246.99",
	},
	&fronted.Masquerade{
		Domain:    "gahe.com",
		IpAddress: "198.41.247.233",
	},
	&fronted.Masquerade{
		Domain:    "gamebaby.com",
		IpAddress: "162.159.242.107",
	},
	&fronted.Masquerade{
		Domain:    "gameninja.com",
		IpAddress: "198.41.189.17",
	},
	&fronted.Masquerade{
		Domain:    "gamepedia.com",
		IpAddress: "190.93.245.101",
	},
	&fronted.Masquerade{
		Domain:    "games.co.id",
		IpAddress: "141.101.113.20",
	},
	&fronted.Masquerade{
		Domain:    "gamescaptain.com",
		IpAddress: "162.159.249.247",
	},
	&fronted.Masquerade{
		Domain:    "gameskwala.com",
		IpAddress: "162.159.241.227",
	},
	&fronted.Masquerade{
		Domain:    "gamingruff.com",
		IpAddress: "162.159.250.14",
	},
	&fronted.Masquerade{
		Domain:    "gazetatema.net",
		IpAddress: "198.41.249.104",
	},
	&fronted.Masquerade{
		Domain:    "gcflearnfree.org",
		IpAddress: "190.93.240.72",
	},
	&fronted.Masquerade{
		Domain:    "geo.tv",
		IpAddress: "141.101.114.11",
	},
	&fronted.Masquerade{
		Domain:    "getsecuredfiles.com",
		IpAddress: "162.159.244.76",
	},
	&fronted.Masquerade{
		Domain:    "getsoftfree.com",
		IpAddress: "162.159.247.115",
	},
	&fronted.Masquerade{
		Domain:    "gfycat.com",
		IpAddress: "190.93.254.72",
	},
	&fronted.Masquerade{
		Domain:    "ghost.org",
		IpAddress: "190.93.247.19",
	},
	&fronted.Masquerade{
		Domain:    "gigacircle.com",
		IpAddress: "104.16.31.35",
	},
	&fronted.Masquerade{
		Domain:    "gilt.com",
		IpAddress: "198.41.209.113",
	},
	&fronted.Masquerade{
		Domain:    "gizmodo.com.au",
		IpAddress: "190.93.247.73",
	},
	&fronted.Masquerade{
		Domain:    "glamora.ma",
		IpAddress: "162.159.250.147",
	},
	&fronted.Masquerade{
		Domain:    "glassdoor.com",
		IpAddress: "190.93.245.224",
	},
	&fronted.Masquerade{
		Domain:    "globalresearch.ca",
		IpAddress: "162.159.247.162",
	},
	&fronted.Masquerade{
		Domain:    "goldentowns.com",
		IpAddress: "162.159.251.240",
	},
	&fronted.Masquerade{
		Domain:    "gooddrama.net",
		IpAddress: "108.162.203.51",
	},
	&fronted.Masquerade{
		Domain:    "goodmenproject.com",
		IpAddress: "162.159.248.216",
	},
	&fronted.Masquerade{
		Domain:    "goodsearch.com",
		IpAddress: "190.93.241.98",
	},
	&fronted.Masquerade{
		Domain:    "gooool.org",
		IpAddress: "162.159.242.194",
	},
	&fronted.Masquerade{
		Domain:    "gottabemobile.com",
		IpAddress: "190.93.243.110",
	},
	&fronted.Masquerade{
		Domain:    "graphpaperpress.com",
		IpAddress: "162.159.250.94",
	},
	&fronted.Masquerade{
		Domain:    "gtspirit.com",
		IpAddress: "162.159.243.151",
	},
	&fronted.Masquerade{
		Domain:    "gurufocus.com",
		IpAddress: "162.159.251.182",
	},
	&fronted.Masquerade{
		Domain:    "haber1903.com",
		IpAddress: "108.162.202.135",
	},
	&fronted.Masquerade{
		Domain:    "hackforums.net",
		IpAddress: "141.101.121.11",
	},
	&fronted.Masquerade{
		Domain:    "haqqin.az",
		IpAddress: "104.20.18.96",
	},
	&fronted.Masquerade{
		Domain:    "hardmob.com.br",
		IpAddress: "141.101.113.96",
	},
	&fronted.Masquerade{
		Domain:    "hearthpwn.com",
		IpAddress: "190.93.246.113",
	},
	&fronted.Masquerade{
		Domain:    "hesport.com",
		IpAddress: "162.159.241.209",
	},
	&fronted.Masquerade{
		Domain:    "hibapress.com",
		IpAddress: "162.159.245.178",
	},
	&fronted.Masquerade{
		Domain:    "highcharts.com",
		IpAddress: "162.159.250.193",
	},
	&fronted.Masquerade{
		Domain:    "hitleap.com",
		IpAddress: "198.41.183.88",
	},
	&fronted.Masquerade{
		Domain:    "hltv.org",
		IpAddress: "162.159.241.196",
	},
	&fronted.Masquerade{
		Domain:    "home.ijreview.com",
		IpAddress: "104.16.3.43",
	},
	&fronted.Masquerade{
		Domain:    "i-fit.com.tw",
		IpAddress: "108.162.201.108",
	},
	&fronted.Masquerade{
		Domain:    "ibuildapp.com",
		IpAddress: "141.101.112.201",
	},
	&fronted.Masquerade{
		Domain:    "ifilez.org",
		IpAddress: "141.101.123.94",
	},
	&fronted.Masquerade{
		Domain:    "iitv.info",
		IpAddress: "162.159.251.221",
	},
	&fronted.Masquerade{
		Domain:    "ikman.lk",
		IpAddress: "162.159.240.243",
	},
	&fronted.Masquerade{
		Domain:    "imgchili.net",
		IpAddress: "104.20.27.113",
	},
	&fronted.Masquerade{
		Domain:    "imgflip.com",
		IpAddress: "141.101.115.143",
	},
	&fronted.Masquerade{
		Domain:    "imgspice.com",
		IpAddress: "198.41.249.212",
	},
	&fronted.Masquerade{
		Domain:    "imscrapidmailer.com",
		IpAddress: "162.159.249.226",
	},
	&fronted.Masquerade{
		Domain:    "imsuccesscenter.com",
		IpAddress: "162.159.251.79",
	},
	&fronted.Masquerade{
		Domain:    "index.hr",
		IpAddress: "198.41.181.4",
	},
	&fronted.Masquerade{
		Domain:    "inflexwetrust.com",
		IpAddress: "162.159.250.202",
	},
	&fronted.Masquerade{
		Domain:    "inforesist.org",
		IpAddress: "108.162.206.29",
	},
	&fronted.Masquerade{
		Domain:    "informe21.com",
		IpAddress: "162.159.244.121",
	},
	&fronted.Masquerade{
		Domain:    "intercambiosvirtuales.org",
		IpAddress: "162.159.243.146",
	},
	&fronted.Masquerade{
		Domain:    "ionicframework.com",
		IpAddress: "162.159.247.203",
	},
	&fronted.Masquerade{
		Domain:    "ipiccy.com",
		IpAddress: "190.93.240.33",
	},
	&fronted.Masquerade{
		Domain:    "iplocation.net",
		IpAddress: "104.20.15.186",
	},
	&fronted.Masquerade{
		Domain:    "iptorrents.com",
		IpAddress: "190.93.243.131",
	},
	&fronted.Masquerade{
		Domain:    "israelvideonetwork.com",
		IpAddress: "198.41.184.73",
	},
	&fronted.Masquerade{
		Domain:    "italia-film.org",
		IpAddress: "141.101.123.91",
	},
	&fronted.Masquerade{
		Domain:    "iwebchk.com",
		IpAddress: "162.159.241.191",
	},
	&fronted.Masquerade{
		Domain:    "ixl.com",
		IpAddress: "190.93.247.136",
	},
	&fronted.Masquerade{
		Domain:    "j.gs",
		IpAddress: "162.159.251.35",
	},
	&fronted.Masquerade{
		Domain:    "jamiiforums.com",
		IpAddress: "162.159.241.71",
	},
	&fronted.Masquerade{
		Domain:    "jeuneafrique.com",
		IpAddress: "162.159.249.152",
	},
	&fronted.Masquerade{
		Domain:    "joomla.fr",
		IpAddress: "162.159.246.52",
	},
	&fronted.Masquerade{
		Domain:    "jquery.com",
		IpAddress: "104.16.15.15",
	},
	&fronted.Masquerade{
		Domain:    "jquerymobile.com",
		IpAddress: "104.16.11.13",
	},
	&fronted.Masquerade{
		Domain:    "jqueryui.com",
		IpAddress: "104.16.3.14",
	},
	&fronted.Masquerade{
		Domain:    "jumia.com.ng",
		IpAddress: "198.41.187.216",
	},
	&fronted.Masquerade{
		Domain:    "k2s.cc",
		IpAddress: "162.159.245.42",
	},
	&fronted.Masquerade{
		Domain:    "karatbars.com",
		IpAddress: "205.204.91.35",
	},
	&fronted.Masquerade{
		Domain:    "karnaval.com",
		IpAddress: "141.101.121.196",
	},
	&fronted.Masquerade{
		Domain:    "kaymu.com.ng",
		IpAddress: "104.20.27.2",
	},
	&fronted.Masquerade{
		Domain:    "kaymu.pk",
		IpAddress: "141.101.112.175",
	},
	&fronted.Masquerade{
		Domain:    "kickerdaily.com",
		IpAddress: "162.159.241.39",
	},
	&fronted.Masquerade{
		Domain:    "kidsactivitiesblog.com",
		IpAddress: "162.159.247.80",
	},
	&fronted.Masquerade{
		Domain:    "kinogo.net",
		IpAddress: "190.93.254.44",
	},
	&fronted.Masquerade{
		Domain:    "kinoman.tv",
		IpAddress: "190.93.253.89",
	},
	&fronted.Masquerade{
		Domain:    "klix.ba",
		IpAddress: "190.93.241.87",
	},
	&fronted.Masquerade{
		Domain:    "korben.info",
		IpAddress: "162.159.250.186",
	},
	&fronted.Masquerade{
		Domain:    "kwejk.pl",
		IpAddress: "162.159.255.37",
	},
	&fronted.Masquerade{
		Domain:    "ladygames.com",
		IpAddress: "162.159.241.107",
	},
	&fronted.Masquerade{
		Domain:    "lamido.co.id",
		IpAddress: "198.41.188.224",
	},
	&fronted.Masquerade{
		Domain:    "lapatilla.com",
		IpAddress: "141.101.123.240",
	},
	&fronted.Masquerade{
		Domain:    "lasvegassun.com",
		IpAddress: "190.93.240.129",
	},
	&fronted.Masquerade{
		Domain:    "laughingsquid.com",
		IpAddress: "162.159.248.97",
	},
	&fronted.Masquerade{
		Domain:    "lbcgroup.tv",
		IpAddress: "190.93.241.50",
	},
	&fronted.Masquerade{
		Domain:    "legacyclix.com",
		IpAddress: "162.159.249.65",
	},
	&fronted.Masquerade{
		Domain:    "legiaodosherois.com.br",
		IpAddress: "162.159.245.5",
	},
	&fronted.Masquerade{
		Domain:    "libertyland.tv",
		IpAddress: "162.159.253.102",
	},
	&fronted.Masquerade{
		Domain:    "lifebuzz.com",
		IpAddress: "162.159.243.246",
	},
	&fronted.Masquerade{
		Domain:    "lifehacker.com.au",
		IpAddress: "141.101.114.74",
	},
	&fronted.Masquerade{
		Domain:    "likemag.com",
		IpAddress: "162.159.251.215",
	},
	&fronted.Masquerade{
		Domain:    "likes.com",
		IpAddress: "190.93.247.34",
	},
	&fronted.Masquerade{
		Domain:    "listenpersian.net",
		IpAddress: "162.159.251.9",
	},
	&fronted.Masquerade{
		Domain:    "livefootballol.com",
		IpAddress: "162.159.246.67",
	},
	&fronted.Masquerade{
		Domain:    "livefootballvideo.com",
		IpAddress: "108.162.202.76",
	},
	&fronted.Masquerade{
		Domain:    "localbitcoins.com",
		IpAddress: "104.20.31.3",
	},
	&fronted.Masquerade{
		Domain:    "lowendbox.com",
		IpAddress: "190.93.253.64",
	},
	&fronted.Masquerade{
		Domain:    "lowendtalk.com",
		IpAddress: "190.93.255.75",
	},
	&fronted.Masquerade{
		Domain:    "maannews.net",
		IpAddress: "198.41.180.81",
	},
	&fronted.Masquerade{
		Domain:    "macacovelho.com.br",
		IpAddress: "198.41.188.108",
	},
	&fronted.Masquerade{
		Domain:    "macworld.co.uk",
		IpAddress: "104.16.14.54",
	},
	&fronted.Masquerade{
		Domain:    "madmimi.com",
		IpAddress: "141.101.113.192",
	},
	&fronted.Masquerade{
		Domain:    "mafiashare.net",
		IpAddress: "141.101.120.97",
	},
	&fronted.Masquerade{
		Domain:    "makeagif.com",
		IpAddress: "162.159.248.46",
	},
	&fronted.Masquerade{
		Domain:    "makeupandbeauty.com",
		IpAddress: "190.93.254.95",
	},
	&fronted.Masquerade{
		Domain:    "mamamia.com.au",
		IpAddress: "162.159.244.187",
	},
	&fronted.Masquerade{
		Domain:    "manicomio-share.com",
		IpAddress: "198.41.206.93",
	},
	&fronted.Masquerade{
		Domain:    "manygames.com",
		IpAddress: "162.159.241.107",
	},
	&fronted.Masquerade{
		Domain:    "maplestage.com",
		IpAddress: "162.159.253.194",
	},
	&fronted.Masquerade{
		Domain:    "marketinggenesis.com",
		IpAddress: "162.159.250.110",
	},
	&fronted.Masquerade{
		Domain:    "marunadanmalayali.com",
		IpAddress: "141.101.126.226",
	},
	&fronted.Masquerade{
		Domain:    "matchesfashion.com",
		IpAddress: "198.41.188.14",
	},
	&fronted.Masquerade{
		Domain:    "mazika2day.com",
		IpAddress: "198.41.204.242",
	},
	&fronted.Masquerade{
		Domain:    "media-fire.org",
		IpAddress: "198.41.185.89",
	},
	&fronted.Masquerade{
		Domain:    "medialoot.com",
		IpAddress: "162.159.240.192",
	},
	&fronted.Masquerade{
		Domain:    "megafilmeshd.net",
		IpAddress: "198.41.185.137",
	},
	&fronted.Masquerade{
		Domain:    "mg.co.za",
		IpAddress: "162.159.244.60",
	},
	&fronted.Masquerade{
		Domain:    "microworkers.com",
		IpAddress: "190.93.243.147",
	},
	&fronted.Masquerade{
		Domain:    "minecraftforum.net",
		IpAddress: "141.101.114.118",
	},
	&fronted.Masquerade{
		Domain:    "minecraftservers.org",
		IpAddress: "190.93.242.14",
	},
	&fronted.Masquerade{
		Domain:    "missmalini.com",
		IpAddress: "198.41.249.41",
	},
	&fronted.Masquerade{
		Domain:    "mixedmartialarts.com",
		IpAddress: "190.93.243.56",
	},
	&fronted.Masquerade{
		Domain:    "mixergy.com",
		IpAddress: "162.159.251.147",
	},
	&fronted.Masquerade{
		Domain:    "mmo-champion.com",
		IpAddress: "190.93.244.118",
	},
	&fronted.Masquerade{
		Domain:    "mo.gov",
		IpAddress: "104.16.23.39",
	},
	&fronted.Masquerade{
		Domain:    "mobafire.com",
		IpAddress: "141.101.121.20",
	},
	&fronted.Masquerade{
		Domain:    "modern.az",
		IpAddress: "108.162.206.159",
	},
	&fronted.Masquerade{
		Domain:    "moneyplatform.biz",
		IpAddress: "108.162.201.215",
	},
	&fronted.Masquerade{
		Domain:    "monitorbacklinks.com",
		IpAddress: "162.159.240.25",
	},
	&fronted.Masquerade{
		Domain:    "morguefile.com",
		IpAddress: "162.159.247.132",
	},
	&fronted.Masquerade{
		Domain:    "mylikes.com",
		IpAddress: "190.93.245.37",
	},
	&fronted.Masquerade{
		Domain:    "naijaloaded.com.ng",
		IpAddress: "141.101.126.140",
	},
	&fronted.Masquerade{
		Domain:    "nairaland.com",
		IpAddress: "198.41.184.68",
	},
	&fronted.Masquerade{
		Domain:    "naosalvo.com.br",
		IpAddress: "108.162.207.184",
	},
	&fronted.Masquerade{
		Domain:    "nbadraft.net",
		IpAddress: "162.159.251.170",
	},
	&fronted.Masquerade{
		Domain:    "nerdfitness.com",
		IpAddress: "162.159.243.153",
	},
	&fronted.Masquerade{
		Domain:    "network-tools.com",
		IpAddress: "141.101.123.110",
	},
	&fronted.Masquerade{
		Domain:    "network54.com",
		IpAddress: "162.159.249.43",
	},
	&fronted.Masquerade{
		Domain:    "new.elfagr.org",
		IpAddress: "198.41.189.53",
	},
	&fronted.Masquerade{
		Domain:    "newmobilelife.com",
		IpAddress: "141.101.124.54",
	},
	&fronted.Masquerade{
		Domain:    "nextinpact.com",
		IpAddress: "162.159.249.65",
	},
	&fronted.Masquerade{
		Domain:    "nextmedia.com",
		IpAddress: "104.16.9.5",
	},
	&fronted.Masquerade{
		Domain:    "ngrguardiannews.com",
		IpAddress: "162.159.240.185",
	},
	&fronted.Masquerade{
		Domain:    "niebezpiecznik.pl",
		IpAddress: "198.41.203.16",
	},
	&fronted.Masquerade{
		Domain:    "noticiaaldia.com",
		IpAddress: "198.41.181.92",
	},
	&fronted.Masquerade{
		Domain:    "noticierodigital.com",
		IpAddress: "190.93.243.95",
	},
	&fronted.Masquerade{
		Domain:    "ocioso.com.br",
		IpAddress: "108.162.204.94",
	},
	&fronted.Masquerade{
		Domain:    "ojooo.com",
		IpAddress: "198.41.190.230",
	},
	&fronted.Masquerade{
		Domain:    "omgtorrent.com",
		IpAddress: "198.41.200.19",
	},
	&fronted.Masquerade{
		Domain:    "onegreenplanet.org",
		IpAddress: "162.159.243.192",
	},
	&fronted.Masquerade{
		Domain:    "oneplus.net",
		IpAddress: "141.101.126.10",
	},
	&fronted.Masquerade{
		Domain:    "onlineclock.net",
		IpAddress: "190.93.251.94",
	},
	&fronted.Masquerade{
		Domain:    "onlinesoccermanager.com",
		IpAddress: "162.159.252.18",
	},
	&fronted.Masquerade{
		Domain:    "opencart.com",
		IpAddress: "104.20.14.19",
	},
	&fronted.Masquerade{
		Domain:    "opensoftwareupdater.com",
		IpAddress: "162.159.248.241",
	},
	&fronted.Masquerade{
		Domain:    "opposingviews.com",
		IpAddress: "162.159.254.200",
	},
	&fronted.Masquerade{
		Domain:    "optionow.com",
		IpAddress: "190.93.241.94",
	},
	&fronted.Masquerade{
		Domain:    "oscaro.com",
		IpAddress: "104.16.13.97",
	},
	&fronted.Masquerade{
		Domain:    "osdir.com",
		IpAddress: "162.159.255.185",
	},
	&fronted.Masquerade{
		Domain:    "oyunkolu.com",
		IpAddress: "162.159.248.209",
	},
	&fronted.Masquerade{
		Domain:    "palemoon.org",
		IpAddress: "162.159.252.211",
	},
	&fronted.Masquerade{
		Domain:    "pangu.io",
		IpAddress: "108.162.201.127",
	},
	&fronted.Masquerade{
		Domain:    "parimatch.com",
		IpAddress: "198.41.190.97",
	},
	&fronted.Masquerade{
		Domain:    "partis.si",
		IpAddress: "108.162.201.127",
	},
	&fronted.Masquerade{
		Domain:    "pastebin.com",
		IpAddress: "190.93.242.15",
	},
	&fronted.Masquerade{
		Domain:    "pcadvisor.co.uk",
		IpAddress: "104.16.27.51",
	},
	&fronted.Masquerade{
		Domain:    "pelis24.com",
		IpAddress: "198.41.189.143",
	},
	&fronted.Masquerade{
		Domain:    "photoyoum7.com",
		IpAddress: "104.16.7.117",
	},
	&fronted.Masquerade{
		Domain:    "pijamasurf.com",
		IpAddress: "162.159.242.249",
	},
	&fronted.Masquerade{
		Domain:    "piktochart.com",
		IpAddress: "162.159.246.70",
	},
	&fronted.Masquerade{
		Domain:    "pixroute.com",
		IpAddress: "162.159.242.52",
	},
	&fronted.Masquerade{
		Domain:    "planetminecraft.com",
		IpAddress: "190.93.242.126",
	},
	&fronted.Masquerade{
		Domain:    "playit.pk",
		IpAddress: "162.159.241.198",
	},
	&fronted.Masquerade{
		Domain:    "plp.cl",
		IpAddress: "198.41.200.28",
	},
	&fronted.Masquerade{
		Domain:    "podomatic.com",
		IpAddress: "104.20.21.4",
	},
	&fronted.Masquerade{
		Domain:    "podrobnosti.ua",
		IpAddress: "198.41.181.97",
	},
	&fronted.Masquerade{
		Domain:    "popcash.net",
		IpAddress: "162.159.244.37",
	},
	&fronted.Masquerade{
		Domain:    "popnhop.com",
		IpAddress: "162.159.248.205",
	},
	&fronted.Masquerade{
		Domain:    "post852.com",
		IpAddress: "198.41.191.113",
	},
	&fronted.Masquerade{
		Domain:    "postcron.com",
		IpAddress: "162.159.242.38",
	},
	&fronted.Masquerade{
		Domain:    "postto.me",
		IpAddress: "141.101.120.157",
	},
	&fronted.Masquerade{
		Domain:    "premium.wpmudev.org",
		IpAddress: "104.16.25.10",
	},
	&fronted.Masquerade{
		Domain:    "premiumwp.com",
		IpAddress: "162.159.250.100",
	},
	&fronted.Masquerade{
		Domain:    "prlog.ru",
		IpAddress: "162.159.242.63",
	},
	&fronted.Masquerade{
		Domain:    "prntscr.com",
		IpAddress: "198.41.191.131",
	},
	&fronted.Masquerade{
		Domain:    "proprofs.com",
		IpAddress: "198.41.206.245",
	},
	&fronted.Masquerade{
		Domain:    "prosperent.com",
		IpAddress: "162.159.240.24",
	},
	&fronted.Masquerade{
		Domain:    "proteusthemes.com",
		IpAddress: "162.159.248.215",
	},
	&fronted.Masquerade{
		Domain:    "proxybay.info",
		IpAddress: "91.236.116.48",
	},
	&fronted.Masquerade{
		Domain:    "ptcstair.com",
		IpAddress: "162.159.250.107",
	},
	&fronted.Masquerade{
		Domain:    "puu.sh",
		IpAddress: "162.159.243.139",
	},
	&fronted.Masquerade{
		Domain:    "q.gs",
		IpAddress: "162.159.247.88",
	},
	&fronted.Masquerade{
		Domain:    "qatarliving.com",
		IpAddress: "198.41.249.175",
	},
	&fronted.Masquerade{
		Domain:    "qol.az",
		IpAddress: "162.159.244.133",
	},
	&fronted.Masquerade{
		Domain:    "r10.net",
		IpAddress: "162.159.254.82",
	},
	&fronted.Masquerade{
		Domain:    "rapgenius.com",
		IpAddress: "104.16.27.4",
	},
	&fronted.Masquerade{
		Domain:    "rapradar.com",
		IpAddress: "141.101.112.16",
	},
	&fronted.Masquerade{
		Domain:    "rassd.com",
		IpAddress: "198.41.247.222",
	},
	&fronted.Masquerade{
		Domain:    "rcwlightning.com",
		IpAddress: "108.162.200.227",
	},
	&fronted.Masquerade{
		Domain:    "re-direcciona.me",
		IpAddress: "162.159.242.146",
	},
	&fronted.Masquerade{
		Domain:    "repelis.tv",
		IpAddress: "162.159.245.193",
	},
	&fronted.Masquerade{
		Domain:    "reshareworthy.com",
		IpAddress: "108.162.200.123",
	},
	&fronted.Masquerade{
		Domain:    "ritegamer.com",
		IpAddress: "162.159.249.247",
	},
	&fronted.Masquerade{
		Domain:    "riverplate.com",
		IpAddress: "162.159.245.32",
	},
	&fronted.Masquerade{
		Domain:    "rollingout.com",
		IpAddress: "198.41.188.117",
	},
	&fronted.Masquerade{
		Domain:    "rsw-systems.com",
		IpAddress: "104.20.20.116",
	},
	&fronted.Masquerade{
		Domain:    "rudaw.net",
		IpAddress: "190.93.240.83",
	},
	&fronted.Masquerade{
		Domain:    "rus.ec",
		IpAddress: "198.41.187.201",
	},
	&fronted.Masquerade{
		Domain:    "rusvesna.su",
		IpAddress: "162.159.253.6",
	},
	&fronted.Masquerade{
		Domain:    "sa.ae",
		IpAddress: "162.159.240.111",
	},
	&fronted.Masquerade{
		Domain:    "saaid.net",
		IpAddress: "198.41.182.75",
	},
	&fronted.Masquerade{
		Domain:    "sabq.org",
		IpAddress: "141.101.114.116",
	},
	&fronted.Masquerade{
		Domain:    "sanakirja.org",
		IpAddress: "141.101.112.91",
	},
	&fronted.Masquerade{
		Domain:    "say7.info",
		IpAddress: "162.159.245.26",
	},
	&fronted.Masquerade{
		Domain:    "sayidaty.net",
		IpAddress: "108.162.201.30",
	},
	&fronted.Masquerade{
		Domain:    "scotch.io",
		IpAddress: "141.101.126.86",
	},
	&fronted.Masquerade{
		Domain:    "searchengines.guru",
		IpAddress: "190.93.242.113",
	},
	&fronted.Masquerade{
		Domain:    "searchengines.ru",
		IpAddress: "190.93.240.113",
	},
	&fronted.Masquerade{
		Domain:    "seemorgh.com",
		IpAddress: "141.101.120.194",
	},
	&fronted.Masquerade{
		Domain:    "sendgrid.com",
		IpAddress: "104.20.20.26",
	},
	&fronted.Masquerade{
		Domain:    "sergey-mavrodi-mmm.net",
		IpAddress: "162.159.244.38",
	},
	&fronted.Masquerade{
		Domain:    "sergey-mavrodi-mmm.org",
		IpAddress: "162.159.250.160",
	},
	&fronted.Masquerade{
		Domain:    "sergey-mavrodi.com",
		IpAddress: "162.159.254.253",
	},
	&fronted.Masquerade{
		Domain:    "sergeymavrodi.com",
		IpAddress: "162.159.255.203",
	},
	&fronted.Masquerade{
		Domain:    "shahiya.com",
		IpAddress: "162.159.240.128",
	},
	&fronted.Masquerade{
		Domain:    "shapeways.com",
		IpAddress: "198.41.188.36",
	},
	&fronted.Masquerade{
		Domain:    "sheknows.com",
		IpAddress: "162.159.244.215",
	},
	&fronted.Masquerade{
		Domain:    "shippuden.tv",
		IpAddress: "108.162.206.85",
	},
	&fronted.Masquerade{
		Domain:    "shmoop.com",
		IpAddress: "174.34.229.43",
	},
	&fronted.Masquerade{
		Domain:    "siam-movie.com",
		IpAddress: "198.41.179.78",
	},
	&fronted.Masquerade{
		Domain:    "siliconera.com",
		IpAddress: "190.93.245.99",
	},
	&fronted.Masquerade{
		Domain:    "siliconrus.com",
		IpAddress: "198.41.191.66",
	},
	&fronted.Masquerade{
		Domain:    "sinchew.com.my",
		IpAddress: "141.101.121.130",
	},
	&fronted.Masquerade{
		Domain:    "sitetalk.com",
		IpAddress: "190.93.241.207",
	},
	&fronted.Masquerade{
		Domain:    "skladchik.com",
		IpAddress: "104.20.2.89",
	},
	&fronted.Masquerade{
		Domain:    "smallpdf.com",
		IpAddress: "162.159.250.205",
	},
	&fronted.Masquerade{
		Domain:    "smartpassiveincome.com",
		IpAddress: "162.159.243.132",
	},
	&fronted.Masquerade{
		Domain:    "smittenkitchen.com",
		IpAddress: "190.93.240.139",
	},
	&fronted.Masquerade{
		Domain:    "smofast.com",
		IpAddress: "141.101.124.55",
	},
	&fronted.Masquerade{
		Domain:    "smosh.com",
		IpAddress: "162.159.253.34",
	},
	&fronted.Masquerade{
		Domain:    "smotrisport.tv",
		IpAddress: "198.41.178.23",
	},
	&fronted.Masquerade{
		Domain:    "snapengage.com",
		IpAddress: "190.93.241.132",
	},
	&fronted.Masquerade{
		Domain:    "snapwidget.com",
		IpAddress: "162.159.246.49",
	},
	&fronted.Masquerade{
		Domain:    "snip.ly",
		IpAddress: "108.162.202.204",
	},
	&fronted.Masquerade{
		Domain:    "snipplr.com",
		IpAddress: "162.159.250.66",
	},
	&fronted.Masquerade{
		Domain:    "softarchive.net",
		IpAddress: "108.162.202.222",
	},
	&fronted.Masquerade{
		Domain:    "somuch.com",
		IpAddress: "141.101.127.228",
	},
	&fronted.Masquerade{
		Domain:    "songspk.name",
		IpAddress: "108.162.201.183",
	},
	&fronted.Masquerade{
		Domain:    "soompi.com",
		IpAddress: "104.20.18.19",
	},
	&fronted.Masquerade{
		Domain:    "sooperarticles.com",
		IpAddress: "108.162.206.236",
	},
	&fronted.Masquerade{
		Domain:    "sott.net",
		IpAddress: "162.159.250.111",
	},
	&fronted.Masquerade{
		Domain:    "spi0n.com",
		IpAddress: "198.41.183.58",
	},
	&fronted.Masquerade{
		Domain:    "sportbox.az",
		IpAddress: "108.162.206.207",
	},
	&fronted.Masquerade{
		Domain:    "sprotyv.info",
		IpAddress: "141.101.125.17",
	},
	&fronted.Masquerade{
		Domain:    "stadt-bremerhaven.de",
		IpAddress: "198.41.184.16",
	},
	&fronted.Masquerade{
		Domain:    "stagram.com",
		IpAddress: "190.93.240.45",
	},
	&fronted.Masquerade{
		Domain:    "stansberryresearch.com",
		IpAddress: "104.20.26.17",
	},
	&fronted.Masquerade{
		Domain:    "steamdb.info",
		IpAddress: "162.159.254.176",
	},
	&fronted.Masquerade{
		Domain:    "streamallthis.me",
		IpAddress: "162.159.241.171",
	},
	&fronted.Masquerade{
		Domain:    "subscene.com",
		IpAddress: "162.159.250.9",
	},
	&fronted.Masquerade{
		Domain:    "sudaneseonline.com",
		IpAddress: "198.41.205.254",
	},
	&fronted.Masquerade{
		Domain:    "super.ae",
		IpAddress: "162.159.253.7",
	},
	&fronted.Masquerade{
		Domain:    "survzilla.com",
		IpAddress: "108.162.202.107",
	},
	&fronted.Masquerade{
		Domain:    "t24.com.tr",
		IpAddress: "141.101.126.79",
	},
	&fronted.Masquerade{
		Domain:    "tahrirnews.com",
		IpAddress: "198.41.186.206",
	},
	&fronted.Masquerade{
		Domain:    "tarafdari.com",
		IpAddress: "198.41.190.174",
	},
	&fronted.Masquerade{
		Domain:    "tech-recipes.com",
		IpAddress: "108.162.207.86",
	},
	&fronted.Masquerade{
		Domain:    "tecnoblog.net",
		IpAddress: "108.162.205.195",
	},
	&fronted.Masquerade{
		Domain:    "teebik.com",
		IpAddress: "198.41.189.108",
	},
	&fronted.Masquerade{
		Domain:    "templatemonster.com",
		IpAddress: "190.93.254.48",
	},
	&fronted.Masquerade{
		Domain:    "temptalia.com",
		IpAddress: "108.162.200.113",
	},
	&fronted.Masquerade{
		Domain:    "terafile.co",
		IpAddress: "162.159.250.139",
	},
	&fronted.Masquerade{
		Domain:    "tert.am",
		IpAddress: "108.162.201.195",
	},
	&fronted.Masquerade{
		Domain:    "teveonline.net",
		IpAddress: "198.41.204.151",
	},
	&fronted.Masquerade{
		Domain:    "tgju.org",
		IpAddress: "198.41.206.180",
	},
	&fronted.Masquerade{
		Domain:    "the-open-mind.com",
		IpAddress: "141.101.126.65",
	},
	&fronted.Masquerade{
		Domain:    "thebot.net",
		IpAddress: "162.159.248.116",
	},
	&fronted.Masquerade{
		Domain:    "thediplomat.com",
		IpAddress: "198.41.249.234",
	},
	&fronted.Masquerade{
		Domain:    "thedirty.com",
		IpAddress: "141.101.112.32",
	},
	&fronted.Masquerade{
		Domain:    "thefile.me",
		IpAddress: "162.159.255.32",
	},
	&fronted.Masquerade{
		Domain:    "thefreethoughtproject.com",
		IpAddress: "162.159.240.157",
	},
	&fronted.Masquerade{
		Domain:    "thehackernews.com",
		IpAddress: "162.159.247.166",
	},
	&fronted.Masquerade{
		Domain:    "theladbible.com",
		IpAddress: "198.41.215.5",
	},
	&fronted.Masquerade{
		Domain:    "themattwalshblog.com",
		IpAddress: "108.162.203.50",
	},
	&fronted.Masquerade{
		Domain:    "theme-fusion.com",
		IpAddress: "104.20.26.96",
	},
	&fronted.Masquerade{
		Domain:    "thenationonlineng.net",
		IpAddress: "162.159.252.179",
	},
	&fronted.Masquerade{
		Domain:    "thenewstribe.com",
		IpAddress: "162.159.247.82",
	},
	&fronted.Masquerade{
		Domain:    "thepioneerwoman.com",
		IpAddress: "198.41.186.138",
	},
	&fronted.Masquerade{
		Domain:    "thepointsguy.com",
		IpAddress: "162.159.249.114",
	},
	&fronted.Masquerade{
		Domain:    "therakyatpost.com",
		IpAddress: "198.41.189.177",
	},
	&fronted.Masquerade{
		Domain:    "thesportbible.com",
		IpAddress: "190.93.247.96",
	},
	&fronted.Masquerade{
		Domain:    "thevideo.me",
		IpAddress: "162.159.242.240",
	},
	&fronted.Masquerade{
		Domain:    "thisiswhyimbroke.com",
		IpAddress: "162.159.250.214",
	},
	&fronted.Masquerade{
		Domain:    "tickld.com",
		IpAddress: "104.16.26.6",
	},
	&fronted.Masquerade{
		Domain:    "tielabs.com",
		IpAddress: "162.159.244.157",
	},
	&fronted.Masquerade{
		Domain:    "tivionline.vn",
		IpAddress: "198.41.202.81",
	},
	&fronted.Masquerade{
		Domain:    "todayifoundout.com",
		IpAddress: "141.101.126.98",
	},
	&fronted.Masquerade{
		Domain:    "torlock.com",
		IpAddress: "198.41.201.25",
	},
	&fronted.Masquerade{
		Domain:    "torrentfreak.com",
		IpAddress: "162.159.246.23",
	},
	&fronted.Masquerade{
		Domain:    "torrentleech.org",
		IpAddress: "108.162.200.95",
	},
	&fronted.Masquerade{
		Domain:    "totalfratmove.com",
		IpAddress: "162.159.249.35",
	},
	&fronted.Masquerade{
		Domain:    "trafficgenesis.com",
		IpAddress: "162.159.241.133",
	},
	&fronted.Masquerade{
		Domain:    "tribalfootball.com",
		IpAddress: "141.101.112.4",
	},
	&fronted.Masquerade{
		Domain:    "tripleclicks.com",
		IpAddress: "141.101.125.214",
	},
	&fronted.Masquerade{
		Domain:    "tructiepbongda.com",
		IpAddress: "198.41.200.45",
	},
	&fronted.Masquerade{
		Domain:    "trueactivist.com",
		IpAddress: "162.159.253.134",
	},
	&fronted.Masquerade{
		Domain:    "tutsplus.com",
		IpAddress: "190.93.241.15",
	},
	&fronted.Masquerade{
		Domain:    "tuvaro.com",
		IpAddress: "162.159.251.141",
	},
	&fronted.Masquerade{
		Domain:    "twentytwowords.com",
		IpAddress: "162.159.245.22",
	},
	&fronted.Masquerade{
		Domain:    "udemy.com",
		IpAddress: "141.101.112.23",
	},
	&fronted.Masquerade{
		Domain:    "ummat.net",
		IpAddress: "141.101.124.43",
	},
	&fronted.Masquerade{
		Domain:    "uniladmag.com",
		IpAddress: "190.93.242.37",
	},
	&fronted.Masquerade{
		Domain:    "unwire.hk",
		IpAddress: "198.41.186.172",
	},
	&fronted.Masquerade{
		Domain:    "updatenowpro.com",
		IpAddress: "162.159.243.60",
	},
	&fronted.Masquerade{
		Domain:    "updatersoft.com",
		IpAddress: "162.159.249.72",
	},
	&fronted.Masquerade{
		Domain:    "uploadboy.com",
		IpAddress: "141.101.125.9",
	},
	&fronted.Masquerade{
		Domain:    "uppit.com",
		IpAddress: "162.159.240.136",
	},
	&fronted.Masquerade{
		Domain:    "uptimerobot.com",
		IpAddress: "141.101.127.239",
	},
	&fronted.Masquerade{
		Domain:    "uptobox.com",
		IpAddress: "190.93.240.95",
	},
	&fronted.Masquerade{
		Domain:    "urbanfonts.com",
		IpAddress: "162.159.240.64",
	},
	&fronted.Masquerade{
		Domain:    "urdupoint.com",
		IpAddress: "162.159.241.213",
	},
	&fronted.Masquerade{
		Domain:    "verseriesynovelas.com",
		IpAddress: "198.41.188.202",
	},
	&fronted.Masquerade{
		Domain:    "vertele.com",
		IpAddress: "162.159.244.94",
	},
	&fronted.Masquerade{
		Domain:    "vetogate.com",
		IpAddress: "190.93.254.146",
	},
	&fronted.Masquerade{
		Domain:    "vidbull.com",
		IpAddress: "162.159.246.224",
	},
	&fronted.Masquerade{
		Domain:    "video.az",
		IpAddress: "198.41.207.238",
	},
	&fronted.Masquerade{
		Domain:    "videomega.tv",
		IpAddress: "162.159.253.156",
	},
	&fronted.Masquerade{
		Domain:    "videostripe.com",
		IpAddress: "198.41.186.157",
	},
	&fronted.Masquerade{
		Domain:    "videoyoum7.com",
		IpAddress: "104.16.24.116",
	},
	&fronted.Masquerade{
		Domain:    "viralistas.com",
		IpAddress: "108.162.205.182",
	},
	&fronted.Masquerade{
		Domain:    "vitorrent.org",
		IpAddress: "162.159.244.211",
	},
	&fronted.Masquerade{
		Domain:    "vladtv.com",
		IpAddress: "162.159.254.30",
	},
	&fronted.Masquerade{
		Domain:    "vodlocker.com",
		IpAddress: "162.159.247.224",
	},
	&fronted.Masquerade{
		Domain:    "vodly.to",
		IpAddress: "190.93.243.35",
	},
	&fronted.Masquerade{
		Domain:    "voetbalzone.nl",
		IpAddress: "198.41.185.200",
	},
	&fronted.Masquerade{
		Domain:    "vr-zone.com",
		IpAddress: "162.159.251.175",
	},
	&fronted.Masquerade{
		Domain:    "watch32.com",
		IpAddress: "162.159.247.45",
	},
	&fronted.Masquerade{
		Domain:    "watchfreemovies.ch",
		IpAddress: "141.101.123.21",
	},
	&fronted.Masquerade{
		Domain:    "watchseries-online.ch",
		IpAddress: "162.159.250.150",
	},
	&fronted.Masquerade{
		Domain:    "watchserieshd.eu",
		IpAddress: "162.159.252.131",
	},
	&fronted.Masquerade{
		Domain:    "webcamtoy.com",
		IpAddress: "162.159.244.254",
	},
	&fronted.Masquerade{
		Domain:    "webdesignerdepot.com",
		IpAddress: "198.41.249.100",
	},
	&fronted.Masquerade{
		Domain:    "weknowmemes.com",
		IpAddress: "162.159.252.34",
	},
	&fronted.Masquerade{
		Domain:    "what-character-are-you.com",
		IpAddress: "162.159.240.83",
	},
	&fronted.Masquerade{
		Domain:    "what.cd",
		IpAddress: "198.41.188.106",
	},
	&fronted.Masquerade{
		Domain:    "whatculture.com",
		IpAddress: "198.41.249.80",
	},
	&fronted.Masquerade{
		Domain:    "wholehk.com",
		IpAddress: "198.41.204.227",
	},
	&fronted.Masquerade{
		Domain:    "wikiwiki.jp",
		IpAddress: "190.93.242.68",
	},
	&fronted.Masquerade{
		Domain:    "wiziq.com",
		IpAddress: "190.93.244.247",
	},
	&fronted.Masquerade{
		Domain:    "wiziwig.tv",
		IpAddress: "198.41.185.160",
	},
	&fronted.Masquerade{
		Domain:    "wmpoweruser.com",
		IpAddress: "162.159.246.134",
	},
	&fronted.Masquerade{
		Domain:    "woorank.com",
		IpAddress: "190.93.242.25",
	},
	&fronted.Masquerade{
		Domain:    "www.4chan.org",
		IpAddress: "141.101.114.6",
	},
	&fronted.Masquerade{
		Domain:    "www.aciprensa.com",
		IpAddress: "198.41.184.167",
	},
	&fronted.Masquerade{
		Domain:    "www.addtoany.com",
		IpAddress: "141.101.125.160",
	},
	&fronted.Masquerade{
		Domain:    "www.altibbi.com",
		IpAddress: "108.162.203.135",
	},
	&fronted.Masquerade{
		Domain:    "www.alweeam.com.sa",
		IpAddress: "141.101.126.49",
	},
	&fronted.Masquerade{
		Domain:    "www.animenewsnetwork.com",
		IpAddress: "198.41.177.81",
	},
	&fronted.Masquerade{
		Domain:    "www.autostraddle.com",
		IpAddress: "162.159.248.115",
	},
	&fronted.Masquerade{
		Domain:    "www.bien.hu",
		IpAddress: "162.159.244.232",
	},
	&fronted.Masquerade{
		Domain:    "www.binary.com",
		IpAddress: "190.93.240.81",
	},
	&fronted.Masquerade{
		Domain:    "www.bj2.me",
		IpAddress: "141.101.123.108",
	},
	&fronted.Masquerade{
		Domain:    "www.brasil247.com",
		IpAddress: "162.159.251.62",
	},
	&fronted.Masquerade{
		Domain:    "www.bulletproofexec.com",
		IpAddress: "104.20.11.19",
	},
	&fronted.Masquerade{
		Domain:    "www.burnews.com",
		IpAddress: "190.93.243.102",
	},
	&fronted.Masquerade{
		Domain:    "www.cairodar.com",
		IpAddress: "104.16.26.116",
	},
	&fronted.Masquerade{
		Domain:    "www.cairoportal.com",
		IpAddress: "108.162.205.162",
	},
	&fronted.Masquerade{
		Domain:    "www.campingworld.com",
		IpAddress: "141.101.112.210",
	},
	&fronted.Masquerade{
		Domain:    "www.caracoltv.com",
		IpAddress: "141.101.123.64",
	},
	&fronted.Masquerade{
		Domain:    "www.cbinsights.com",
		IpAddress: "162.159.249.250",
	},
	&fronted.Masquerade{
		Domain:    "www.change.org",
		IpAddress: "104.16.5.13",
	},
	&fronted.Masquerade{
		Domain:    "www.clubedohardware.com.br",
		IpAddress: "108.162.200.29",
	},
	&fronted.Masquerade{
		Domain:    "www.connectify.me",
		IpAddress: "141.101.112.191",
	},
	&fronted.Masquerade{
		Domain:    "www.cozi.com",
		IpAddress: "162.159.240.100",
	},
	&fronted.Masquerade{
		Domain:    "www.cpalead.com",
		IpAddress: "198.41.188.57",
	},
	&fronted.Masquerade{
		Domain:    "www.cryptocoinsnews.com",
		IpAddress: "104.20.5.21",
	},
	&fronted.Masquerade{
		Domain:    "www.cssauthor.com",
		IpAddress: "108.162.205.9",
	},
	&fronted.Masquerade{
		Domain:    "www.cyanogenmod.org",
		IpAddress: "162.159.245.104",
	},
	&fronted.Masquerade{
		Domain:    "www.davidicke.com",
		IpAddress: "198.41.187.87",
	},
	&fronted.Masquerade{
		Domain:    "www.dawn.com",
		IpAddress: "162.159.242.171",
	},
	&fronted.Masquerade{
		Domain:    "www.daz3d.com",
		IpAddress: "190.93.241.173",
	},
	&fronted.Masquerade{
		Domain:    "www.desi-tashan.com",
		IpAddress: "198.41.247.243",
	},
	&fronted.Masquerade{
		Domain:    "www.diggita.it",
		IpAddress: "162.159.245.162",
	},
	&fronted.Masquerade{
		Domain:    "www.digitalpoint.com",
		IpAddress: "162.159.243.121",
	},
	&fronted.Masquerade{
		Domain:    "www.doomovieonline.com",
		IpAddress: "162.159.244.88",
	},
	&fronted.Masquerade{
		Domain:    "www.ekino.tv",
		IpAddress: "162.159.247.209",
	},
	&fronted.Masquerade{
		Domain:    "www.emailmeform.com",
		IpAddress: "104.16.15.9",
	},
	&fronted.Masquerade{
		Domain:    "www.erepublik.com",
		IpAddress: "108.162.205.105",
	},
	&fronted.Masquerade{
		Domain:    "www.ezilon.com",
		IpAddress: "190.93.241.65",
	},
	&fronted.Masquerade{
		Domain:    "www.fatosdesconhecidos.com.br",
		IpAddress: "190.93.250.4",
	},
	&fronted.Masquerade{
		Domain:    "www.filmpertutti.eu",
		IpAddress: "162.159.246.197",
	},
	&fronted.Masquerade{
		Domain:    "www.firedrive.com",
		IpAddress: "190.93.246.69",
	},
	&fronted.Masquerade{
		Domain:    "www.foodpanda.in",
		IpAddress: "104.16.0.10",
	},
	&fronted.Masquerade{
		Domain:    "www.forosdelweb.com",
		IpAddress: "141.101.121.37",
	},
	&fronted.Masquerade{
		Domain:    "www.freeonlinegames.com",
		IpAddress: "190.93.241.38",
	},
	&fronted.Masquerade{
		Domain:    "www.frmtr.com",
		IpAddress: "162.159.242.133",
	},
	&fronted.Masquerade{
		Domain:    "www.furaffinity.net",
		IpAddress: "190.93.249.71",
	},
	&fronted.Masquerade{
		Domain:    "www.geenstijl.nl",
		IpAddress: "162.159.254.153",
	},
	&fronted.Masquerade{
		Domain:    "www.giltcity.com",
		IpAddress: "141.101.114.238",
	},
	&fronted.Masquerade{
		Domain:    "www.globallshare.com",
		IpAddress: "141.101.127.226",
	},
	&fronted.Masquerade{
		Domain:    "www.grandbux.net",
		IpAddress: "108.162.200.162",
	},
	&fronted.Masquerade{
		Domain:    "www.gulli.com",
		IpAddress: "190.93.243.27",
	},
	&fronted.Masquerade{
		Domain:    "www.hespress.com",
		IpAddress: "162.159.253.98",
	},
	&fronted.Masquerade{
		Domain:    "www.iab.net",
		IpAddress: "141.101.113.75",
	},
	&fronted.Masquerade{
		Domain:    "www.india-forums.com",
		IpAddress: "141.101.127.44",
	},
	&fronted.Masquerade{
		Domain:    "www.infusionsoft.com",
		IpAddress: "198.41.247.138",
	},
	&fronted.Masquerade{
		Domain:    "www.iol.co.za",
		IpAddress: "104.20.31.75",
	},
	&fronted.Masquerade{
		Domain:    "www.jobscore.com",
		IpAddress: "190.93.243.223",
	},
	&fronted.Masquerade{
		Domain:    "www.joe.ie",
		IpAddress: "108.162.202.217",
	},
	&fronted.Masquerade{
		Domain:    "www.jonloomer.com",
		IpAddress: "141.101.126.76",
	},
	&fronted.Masquerade{
		Domain:    "www.joomshaper.com",
		IpAddress: "108.162.205.40",
	},
	&fronted.Masquerade{
		Domain:    "www.jotform.com",
		IpAddress: "141.101.121.40",
	},
	&fronted.Masquerade{
		Domain:    "www.jumia.com.eg",
		IpAddress: "198.41.184.224",
	},
	&fronted.Masquerade{
		Domain:    "www.knownhost.com",
		IpAddress: "162.159.243.146",
	},
	&fronted.Masquerade{
		Domain:    "www.lebanese-forces.com",
		IpAddress: "141.101.121.66",
	},
	&fronted.Masquerade{
		Domain:    "www.levelup.com",
		IpAddress: "162.159.254.190",
	},
	&fronted.Masquerade{
		Domain:    "www.life.com.tw",
		IpAddress: "141.101.112.19",
	},
	&fronted.Masquerade{
		Domain:    "www.like4like.org",
		IpAddress: "141.101.112.76",
	},
	&fronted.Masquerade{
		Domain:    "www.lostfilm.tv",
		IpAddress: "5.199.162.26",
	},
	&fronted.Masquerade{
		Domain:    "www.maduradas.com",
		IpAddress: "162.159.242.224",
	},
	&fronted.Masquerade{
		Domain:    "www.mafa.com",
		IpAddress: "162.159.252.249",
	},
	&fronted.Masquerade{
		Domain:    "www.maxmind.com",
		IpAddress: "141.101.115.190",
	},
	&fronted.Masquerade{
		Domain:    "www.mindtools.com",
		IpAddress: "162.159.252.124",
	},
	&fronted.Masquerade{
		Domain:    "www.mkyong.com",
		IpAddress: "108.162.205.6",
	},
	&fronted.Masquerade{
		Domain:    "www.mobofree.com",
		IpAddress: "162.159.255.219",
	},
	&fronted.Masquerade{
		Domain:    "www.modernghana.com",
		IpAddress: "162.159.253.104",
	},
	&fronted.Masquerade{
		Domain:    "www.mp3xd.com",
		IpAddress: "108.162.206.143",
	},
	&fronted.Masquerade{
		Domain:    "www.myitworks.com",
		IpAddress: "162.159.249.96",
	},
	&fronted.Masquerade{
		Domain:    "www.myvidster.com",
		IpAddress: "198.41.205.6",
	},
	&fronted.Masquerade{
		Domain:    "www.namepros.com",
		IpAddress: "198.41.249.130",
	},
	&fronted.Masquerade{
		Domain:    "www.naointendo.com.br",
		IpAddress: "162.159.243.65",
	},
	&fronted.Masquerade{
		Domain:    "www.newgrounds.com",
		IpAddress: "198.41.187.234",
	},
	&fronted.Masquerade{
		Domain:    "www.nomadicmatt.com",
		IpAddress: "162.159.248.103",
	},
	&fronted.Masquerade{
		Domain:    "www.nthwall.com",
		IpAddress: "104.20.3.28",
	},
	&fronted.Masquerade{
		Domain:    "www.oboom.com",
		IpAddress: "104.20.4.7",
	},
	&fronted.Masquerade{
		Domain:    "www.ofreegames.com",
		IpAddress: "162.159.255.249",
	},
	&fronted.Masquerade{
		Domain:    "www.okcupid.com",
		IpAddress: "198.41.209.131",
	},
	&fronted.Masquerade{
		Domain:    "www.pccomponentes.com",
		IpAddress: "162.159.255.66",
	},
	&fronted.Masquerade{
		Domain:    "www.pdftoword.com",
		IpAddress: "162.159.243.180",
	},
	&fronted.Masquerade{
		Domain:    "www.perrymarshall.com",
		IpAddress: "162.159.251.212",
	},
	&fronted.Masquerade{
		Domain:    "www.plugrush.com",
		IpAddress: "162.159.254.156",
	},
	&fronted.Masquerade{
		Domain:    "www.portalnet.cl",
		IpAddress: "162.159.247.34",
	},
	&fronted.Masquerade{
		Domain:    "www.powned.tv",
		IpAddress: "162.159.245.144",
	},
	&fronted.Masquerade{
		Domain:    "www.preciolandia.com",
		IpAddress: "162.159.242.104",
	},
	&fronted.Masquerade{
		Domain:    "www.primewire.ag",
		IpAddress: "104.20.5.77",
	},
	&fronted.Masquerade{
		Domain:    "www.problogger.net",
		IpAddress: "162.159.249.46",
	},
	&fronted.Masquerade{
		Domain:    "www.producthunt.com",
		IpAddress: "162.159.251.254",
	},
	&fronted.Masquerade{
		Domain:    "www.pushbullet.com",
		IpAddress: "162.159.243.182",
	},
	&fronted.Masquerade{
		Domain:    "www.quadratin.com.mx",
		IpAddress: "162.159.252.44",
	},
	&fronted.Masquerade{
		Domain:    "www.racing-games.com",
		IpAddress: "162.159.254.249",
	},
	&fronted.Masquerade{
		Domain:    "www.rapidvideo.org",
		IpAddress: "162.159.240.68",
	},
	&fronted.Masquerade{
		Domain:    "www.ratemds.com",
		IpAddress: "104.20.20.13",
	},
	&fronted.Masquerade{
		Domain:    "www.renuevodeplenitud.com",
		IpAddress: "162.159.240.79",
	},
	&fronted.Masquerade{
		Domain:    "www.rome2rio.com",
		IpAddress: "108.162.206.115",
	},
	&fronted.Masquerade{
		Domain:    "www.shortlist.com",
		IpAddress: "141.101.123.31",
	},
	&fronted.Masquerade{
		Domain:    "www.sockshare.com",
		IpAddress: "190.93.246.172",
	},
	&fronted.Masquerade{
		Domain:    "www.somethingawful.com",
		IpAddress: "198.41.191.130",
	},
	&fronted.Masquerade{
		Domain:    "www.songspk.name",
		IpAddress: "108.162.202.183",
	},
	&fronted.Masquerade{
		Domain:    "www.ssense.com",
		IpAddress: "104.20.13.4",
	},
	&fronted.Masquerade{
		Domain:    "www.stoiximan.gr",
		IpAddress: "141.101.123.131",
	},
	&fronted.Masquerade{
		Domain:    "www.sundayworld.com",
		IpAddress: "198.41.187.49",
	},
	&fronted.Masquerade{
		Domain:    "www.surveygizmo.com",
		IpAddress: "104.16.18.4",
	},
	&fronted.Masquerade{
		Domain:    "www.sweetfunnycool.com",
		IpAddress: "198.41.249.82",
	},
	&fronted.Masquerade{
		Domain:    "www.techdirt.com",
		IpAddress: "162.159.243.199",
	},
	&fronted.Masquerade{
		Domain:    "www.teefury.com",
		IpAddress: "141.101.112.12",
	},
	&fronted.Masquerade{
		Domain:    "www.thedarewall.com",
		IpAddress: "198.41.185.163",
	},
	&fronted.Masquerade{
		Domain:    "www.thegrommet.com",
		IpAddress: "198.41.188.212",
	},
	&fronted.Masquerade{
		Domain:    "www.theladbible.com",
		IpAddress: "198.41.214.4",
	},
	&fronted.Masquerade{
		Domain:    "www.thingiverse.com",
		IpAddress: "162.159.250.32",
	},
	&fronted.Masquerade{
		Domain:    "www.thisiscolossal.com",
		IpAddress: "108.162.204.135",
	},
	&fronted.Masquerade{
		Domain:    "www.torrentfunk.com",
		IpAddress: "198.41.201.42",
	},
	&fronted.Masquerade{
		Domain:    "www.traidnt.net",
		IpAddress: "141.101.112.65",
	},
	&fronted.Masquerade{
		Domain:    "www.tunisia-sat.com",
		IpAddress: "162.159.243.166",
	},
	&fronted.Masquerade{
		Domain:    "www.tvrage.com",
		IpAddress: "141.101.125.12",
	},
	&fronted.Masquerade{
		Domain:    "www.twickerz.com",
		IpAddress: "162.159.240.235",
	},
	&fronted.Masquerade{
		Domain:    "www.vavel.com",
		IpAddress: "190.93.243.103",
	},
	&fronted.Masquerade{
		Domain:    "www.wayn.com",
		IpAddress: "190.93.243.109",
	},
	&fronted.Masquerade{
		Domain:    "www.webmastersitesi.com",
		IpAddress: "141.101.120.109",
	},
	&fronted.Masquerade{
		Domain:    "www.whatismyip.com",
		IpAddress: "141.101.120.15",
	},
	&fronted.Masquerade{
		Domain:    "www.whmcs.com",
		IpAddress: "104.20.20.8",
	},
	&fronted.Masquerade{
		Domain:    "www.wphub.com",
		IpAddress: "162.159.242.55",
	},
	&fronted.Masquerade{
		Domain:    "www.yokboylebirsey.com.tr",
		IpAddress: "162.159.245.252",
	},
	&fronted.Masquerade{
		Domain:    "www.yougetsignal.com",
		IpAddress: "141.101.127.83",
	},
	&fronted.Masquerade{
		Domain:    "www.zaman.com.tr",
		IpAddress: "190.93.245.170",
	},
	&fronted.Masquerade{
		Domain:    "www.zopim.com",
		IpAddress: "190.93.240.200",
	},
	&fronted.Masquerade{
		Domain:    "www.zumba.com",
		IpAddress: "190.93.245.77",
	},
	&fronted.Masquerade{
		Domain:    "x-kom.pl",
		IpAddress: "104.20.29.24",
	},
	&fronted.Masquerade{
		Domain:    "xat.com",
		IpAddress: "190.93.240.82",
	},
	&fronted.Masquerade{
		Domain:    "xendan.org",
		IpAddress: "108.162.205.126",
	},
	&fronted.Masquerade{
		Domain:    "yell.ru",
		IpAddress: "198.41.191.82",
	},
	&fronted.Masquerade{
		Domain:    "yifysubtitles.com",
		IpAddress: "141.101.127.79",
	},
	&fronted.Masquerade{
		Domain:    "youm7.com",
		IpAddress: "104.16.17.116",
	},
	&fronted.Masquerade{
		Domain:    "yourbittorrent.com",
		IpAddress: "198.41.203.40",
	},
	&fronted.Masquerade{
		Domain:    "yourdailyscoop.com",
		IpAddress: "162.159.249.210",
	},
	&fronted.Masquerade{
		Domain:    "yourvideofile.org",
		IpAddress: "198.41.249.128",
	},
	&fronted.Masquerade{
		Domain:    "yyv.co",
		IpAddress: "190.93.242.65",
	},
	&fronted.Masquerade{
		Domain:    "z6.com",
		IpAddress: "162.159.248.121",
	},
	&fronted.Masquerade{
		Domain:    "zemtv.com",
		IpAddress: "141.101.124.11",
	},
	&fronted.Masquerade{
		Domain:    "zennolab.com",
		IpAddress: "162.159.240.26",
	},
	&fronted.Masquerade{
		Domain:    "zentrum-der-gesundheit.de",
		IpAddress: "141.101.112.102",
	},
	&fronted.Masquerade{
		Domain:    "zerozero.pt",
		IpAddress: "198.41.190.107",
	},
	&fronted.Masquerade{
		Domain:    "zurb.com",
		IpAddress: "104.20.4.2",
	},
	&fronted.Masquerade{
		Domain:    "zwaar.net",
		IpAddress: "162.159.248.231",
	},
}
