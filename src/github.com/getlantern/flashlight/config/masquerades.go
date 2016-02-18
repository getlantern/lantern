package config

import "github.com/getlantern/fronted"

var defaultTrustedCAs = []*CA{
	&CA{
		CommonName: "VeriSign Class 3 Public Primary Certification Authority - G5",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIE0zCCA7ugAwIBAgIQGNrRniZ96LtKIVjNzGs7SjANBgkqhkiG9w0BAQUFADCB\nyjELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\nExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJp\nU2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxW\nZXJpU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0\naG9yaXR5IC0gRzUwHhcNMDYxMTA4MDAwMDAwWhcNMzYwNzE2MjM1OTU5WjCByjEL\nMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZW\nZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2ln\nbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJp\nU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9y\naXR5IC0gRzUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvJAgIKXo1\nnmAMqudLO07cfLw8RRy7K+D+KQL5VwijZIUVJ/XxrcgxiV0i6CqqpkKzj/i5Vbex\nt0uz/o9+B1fs70PbZmIVYc9gDaTY3vjgw2IIPVQT60nKWVSFJuUrjxuf6/WhkcIz\nSdhDY2pSS9KP6HBRTdGJaXvHcPaz3BJ023tdS1bTlr8Vd6Gw9KIl8q8ckmcY5fQG\nBO+QueQA5N06tRn/Arr0PO7gi+s3i+z016zy9vA9r911kTMZHRxAy3QkGSGT2RT+\nrCpSx4/VBEnkjWNHiDxpg8v+R70rfk/Fla4OndTRQ8Bnc+MUCH7lP59zuDMKz10/\nNIeWiu5T6CUVAgMBAAGjgbIwga8wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8E\nBAMCAQYwbQYIKwYBBQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2UvZ2lmMCEwHzAH\nBgUrDgMCGgQUj+XTGoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDovL2xvZ28udmVy\naXNpZ24uY29tL3ZzbG9nby5naWYwHQYDVR0OBBYEFH/TZafC3ey78DAJ80M5+gKv\nMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQCTJEowX2LP2BqYLz3q3JktvXf2pXkiOOzE\np6B4Eq1iDkVwZMXnl2YtmAl+X6/WzChl8gGqCBpH3vn5fJJaCGkgDdk+bW48DW7Y\n5gaRQBi5+MHt39tBquCWIMnNZBU4gcmU7qKEKQsTb47bDN0lAtukixlE0kF6BWlK\nWE9gyn6CagsCqiUXObXbf+eEZSqVir2G3l6BFoMtEMze/aiCKm0oHw0LxOXnGiYZ\n4fQRbxC1lfznQgUy286dUV4otp6F01vvpX1FQHKOtw5rDgb7MzVIcbidJ4vEZV8N\nhnacRHr2lVz2XTIIM6RUthg/aFzyQkqFOFSDX9HoLPKsEdao7WNq\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "Go Daddy Root Certificate Authority - G2",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIBADANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMx\nEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoT\nEUdvRGFkZHkuY29tLCBJbmMuMTEwLwYDVQQDEyhHbyBEYWRkeSBSb290IENlcnRp\nZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIz\nNTk1OVowgYMxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQH\nEwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5LmNvbSwgSW5jLjExMC8GA1UE\nAxMoR28gRGFkZHkgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9xYgjx+lk09xvJGKP3gElY6SKD\nE6bFIEMBO4Tx5oVJnyfq9oQbTqC023CYxzIBsQU+B07u9PpPL1kwIuerGVZr4oAH\n/PMWdYA5UXvl+TW2dE6pjYIT5LY/qQOD+qK+ihVqf94Lw7YZFAXK6sOoBJQ7Rnwy\nDfMAZiLIjWltNowRGLfTshxgtDj6AozO091GB94KPutdfMh8+7ArU6SSYmlRJQVh\nGkSBjCypQ5Yj36w6gZoOKcUcqeldHraenjAKOc7xiID7S13MMuyFYkMlNAJWJwGR\ntDtwKj9useiciAF9n9T521NtYJ2/LOdYq7hfRvzOxBsDPAnrSTFcaUaz4EcCAwEA\nAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE\nFDqahQcQZyi27/a9BUFuIMGU2g/eMA0GCSqGSIb3DQEBCwUAA4IBAQCZ21151fmX\nWWcDYfF+OwYxdS2hII5PZYe096acvNjpL9DbWu7PdIxztDhC2gV7+AJ1uP2lsdeu\n9tfeE8tTEH6KRtGX+rcuKxGrkLAngPnon1rpN5+r5N9ss4UXnT3ZJE95kTXWXwTr\ngIOrmgIttRD02JDHBHNA7XIloKmf7J6raBKZV8aPEjoJpL1E/QYVN8Gb5DKj7Tjo\n2GTzLH4U/ALqn83/B2gX2yKQOC16jdFU8WnjXzPKej17CuPKf1855eJ1usV2GDPO\nLPAvTK33sefOT6jEm0pUBsV/fdUID+Ic/n4XuKxe9tQWskMJDE32p2u0mYRlynqI\n4uJEvlz36hz1\n-----END CERTIFICATE-----\n",
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
		CommonName: "DigiCert Global Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD\nQTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT\nMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j\nb20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG\n9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB\nCSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97\nnh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt\n43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P\nT19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4\ngdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO\nBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR\nTLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw\nDQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr\nhMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg\n06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF\nPnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls\nYSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk\nCAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "DigiCert High Assurance EV Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIQAqxcJmoLQJuPC3nyrkYldzANBgkqhkiG9w0BAQUFADBs\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5j\nZSBFViBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTMxMTExMDAwMDAwMFowbDEL\nMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3\nLmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2Ug\nRVYgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMbM5XPm\n+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRnogocsF9ppkCxxLeyj9CYpKlBWTrT3JTW\nPNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG++MXs2ziS4wblCJEM\nxChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EKmEFB\nIk5lYYeBQVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8VdteZOE3\nhzBWBOURtCmAEvF5OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10aUAsg\nEsxBu24LUTi4S8sCAwEAAaNjMGEwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF\nMAMBAf8wHQYDVR0OBBYEFLE+w2kD+L9HAdSYJhoIAu9jZCvDMB8GA1UdIwQYMBaA\nFLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3DQEBBQUAA4IBAQAcGgaX3Nec\nnzyIZgYIVyHbIUf4KmeqvxgydkAQV8GK83rZEWWONfqe/EW1ntlMMUu4kehDLI6z\neM7b41N5cdblIZQB2lWHmiRk9opmzN6cN82oNLFpmyPInngiK3BD41VHMWEZ71jF\nhS9OMPagMRYjyOfiZRYzy78aG6A9+MpeizGLYAiJLQwGXFK3xPkKmNEVX58Svnw2\nYzi9RKR/5CYrCsSXaQ3pjOLAEFe4yHYSkVXySGnYvCoCWw9E1CAx2/S6cCZdkGCe\nvEsXCS+0yx5DaMkHJ8HSXPfqIbloEpw8nL+e/IBcm2PN7EeqJSdnoDfzAIJ9VNep\n+OkuE6N36B9K\n-----END CERTIFICATE-----\n",
	},
}

var cloudflareMasquerades = []*fronted.Masquerade{}

var cloudfrontMasquerades = []*fronted.Masquerade{
	&fronted.Masquerade{
		Domain:    "101.livere.co.kr",
		IpAddress: "54.182.2.140",
	},
	&fronted.Masquerade{
		Domain:    "1706bbc01.adambank.com",
		IpAddress: "205.251.253.175",
	},
	&fronted.Masquerade{
		Domain:    "1706bbc01.coutts.com",
		IpAddress: "205.251.253.108",
	},
	&fronted.Masquerade{
		Domain:    "1rx.io",
		IpAddress: "54.182.1.196",
	},
	&fronted.Masquerade{
		Domain:    "2015fns-playmusic.com",
		IpAddress: "54.182.1.32",
	},
	&fronted.Masquerade{
		Domain:    "2015fns-playmusic.com",
		IpAddress: "54.239.130.169",
	},
	&fronted.Masquerade{
		Domain:    "2015fns-playmusic.com",
		IpAddress: "54.239.192.198",
	},
	&fronted.Masquerade{
		Domain:    "254a.com",
		IpAddress: "54.239.130.166",
	},
	&fronted.Masquerade{
		Domain:    "2cimple.com",
		IpAddress: "216.137.33.142",
	},
	&fronted.Masquerade{
		Domain:    "2u.com",
		IpAddress: "54.182.1.248",
	},
	&fronted.Masquerade{
		Domain:    "2u.com",
		IpAddress: "54.182.2.45",
	},
	&fronted.Masquerade{
		Domain:    "8thlight.com",
		IpAddress: "204.246.164.191",
	},
	&fronted.Masquerade{
		Domain:    "a-ritani.com",
		IpAddress: "54.182.1.47",
	},
	&fronted.Masquerade{
		Domain:    "a1.adform.net",
		IpAddress: "54.182.2.70",
	},
	&fronted.Masquerade{
		Domain:    "ac.dropboxstatic.com",
		IpAddress: "204.246.164.173",
	},
	&fronted.Masquerade{
		Domain:    "ac.dropboxstatic.com",
		IpAddress: "54.182.0.71",
	},
	&fronted.Masquerade{
		Domain:    "academy.soti.net",
		IpAddress: "54.182.0.211",
	},
	&fronted.Masquerade{
		Domain:    "achievers.com",
		IpAddress: "205.251.253.114",
	},
	&fronted.Masquerade{
		Domain:    "activerideshop.com",
		IpAddress: "54.182.1.133",
	},
	&fronted.Masquerade{
		Domain:    "activerideshop.com",
		IpAddress: "204.246.164.87",
	},
	&fronted.Masquerade{
		Domain:    "adbutter.net",
		IpAddress: "54.182.1.100",
	},
	&fronted.Masquerade{
		Domain:    "adbutter.net",
		IpAddress: "205.251.253.203",
	},
	&fronted.Masquerade{
		Domain:    "adform.net",
		IpAddress: "204.246.164.229",
	},
	&fronted.Masquerade{
		Domain:    "adobelogin.com",
		IpAddress: "54.239.130.90",
	},
	&fronted.Masquerade{
		Domain:    "adobelogin.com",
		IpAddress: "216.137.33.121",
	},
	&fronted.Masquerade{
		Domain:    "adrta.com",
		IpAddress: "54.182.0.6",
	},
	&fronted.Masquerade{
		Domain:    "adtdp.com",
		IpAddress: "216.137.33.71",
	},
	&fronted.Masquerade{
		Domain:    "adtdp.com",
		IpAddress: "54.239.130.29",
	},
	&fronted.Masquerade{
		Domain:    "advisor.bskyb.com",
		IpAddress: "54.182.0.18",
	},
	&fronted.Masquerade{
		Domain:    "adwebster.com",
		IpAddress: "54.182.0.166",
	},
	&fronted.Masquerade{
		Domain:    "adwebster.com",
		IpAddress: "204.246.164.56",
	},
	&fronted.Masquerade{
		Domain:    "aerlingus.com",
		IpAddress: "54.182.0.153",
	},
	&fronted.Masquerade{
		Domain:    "airbnb.com",
		IpAddress: "216.137.33.109",
	},
	&fronted.Masquerade{
		Domain:    "aldebaran.com",
		IpAddress: "204.246.164.134",
	},
	&fronted.Masquerade{
		Domain:    "aldebaran.com",
		IpAddress: "205.251.253.147",
	},
	&fronted.Masquerade{
		Domain:    "aldebaran.com",
		IpAddress: "216.137.33.181",
	},
	&fronted.Masquerade{
		Domain:    "aldebaran.com",
		IpAddress: "54.239.130.147",
	},
	&fronted.Masquerade{
		Domain:    "aldebaran.com",
		IpAddress: "54.239.130.117",
	},
	&fronted.Masquerade{
		Domain:    "altium.com",
		IpAddress: "204.246.169.218",
	},
	&fronted.Masquerade{
		Domain:    "amoad.com",
		IpAddress: "54.182.0.217",
	},
	&fronted.Masquerade{
		Domain:    "amoad.com",
		IpAddress: "204.246.164.7",
	},
	&fronted.Masquerade{
		Domain:    "android.developer.sony.com",
		IpAddress: "216.137.33.82",
	},
	&fronted.Masquerade{
		Domain:    "android.developer.sony.com",
		IpAddress: "54.182.1.99",
	},
	&fronted.Masquerade{
		Domain:    "android.developer.sony.com",
		IpAddress: "205.251.253.70",
	},
	&fronted.Masquerade{
		Domain:    "anypresenceapp.com",
		IpAddress: "54.182.0.218",
	},
	&fronted.Masquerade{
		Domain:    "anypresenceapp.com",
		IpAddress: "204.246.164.91",
	},
	&fronted.Masquerade{
		Domain:    "api.5rocks.io",
		IpAddress: "54.182.0.12",
	},
	&fronted.Masquerade{
		Domain:    "api.beta.tab.com.au",
		IpAddress: "216.137.33.158",
	},
	&fronted.Masquerade{
		Domain:    "api.e1-np.km.playstation.net",
		IpAddress: "54.239.130.21",
	},
	&fronted.Masquerade{
		Domain:    "api.futebol.globosat.tv",
		IpAddress: "205.251.251.166",
	},
	&fronted.Masquerade{
		Domain:    "apotheke.medpex.de",
		IpAddress: "216.137.33.183",
	},
	&fronted.Masquerade{
		Domain:    "apotheke.medpex.de",
		IpAddress: "54.182.0.36",
	},
	&fronted.Masquerade{
		Domain:    "apotheke.medpex.de",
		IpAddress: "205.251.253.197",
	},
	&fronted.Masquerade{
		Domain:    "applause.com",
		IpAddress: "216.137.33.101",
	},
	&fronted.Masquerade{
		Domain:    "applause.com",
		IpAddress: "54.182.1.210",
	},
	&fronted.Masquerade{
		Domain:    "applauze.com",
		IpAddress: "54.182.0.177",
	},
	&fronted.Masquerade{
		Domain:    "apps.lifetechnologies.com",
		IpAddress: "204.246.164.139",
	},
	&fronted.Masquerade{
		Domain:    "apps.lifetechnologies.com",
		IpAddress: "54.182.2.179",
	},
	&fronted.Masquerade{
		Domain:    "appsdownload2.hkjc.com",
		IpAddress: "54.182.0.60",
	},
	&fronted.Masquerade{
		Domain:    "appsdownload2.hkjc.com",
		IpAddress: "204.246.164.239",
	},
	&fronted.Masquerade{
		Domain:    "apxlv.com",
		IpAddress: "216.137.33.80",
	},
	&fronted.Masquerade{
		Domain:    "apxlv.com",
		IpAddress: "54.239.130.206",
	},
	&fronted.Masquerade{
		Domain:    "apxlv.com",
		IpAddress: "54.182.1.128",
	},
	&fronted.Masquerade{
		Domain:    "argusmedia.com",
		IpAddress: "54.182.1.36",
	},
	&fronted.Masquerade{
		Domain:    "artaic.com",
		IpAddress: "54.239.130.110",
	},
	&fronted.Masquerade{
		Domain:    "asics.com",
		IpAddress: "205.251.253.37",
	},
	&fronted.Masquerade{
		Domain:    "ask.fm",
		IpAddress: "205.251.253.156",
	},
	&fronted.Masquerade{
		Domain:    "assets.bwbx.io",
		IpAddress: "54.182.0.24",
	},
	&fronted.Masquerade{
		Domain:    "assets.bwbx.io",
		IpAddress: "54.239.130.177",
	},
	&fronted.Masquerade{
		Domain:    "assets.hosted-commerce.net",
		IpAddress: "54.182.2.180",
	},
	&fronted.Masquerade{
		Domain:    "assets.viralstyle.com",
		IpAddress: "204.246.164.42",
	},
	&fronted.Masquerade{
		Domain:    "assetserv.com",
		IpAddress: "54.182.0.70",
	},
	&fronted.Masquerade{
		Domain:    "assetserv.com",
		IpAddress: "205.251.251.168",
	},
	&fronted.Masquerade{
		Domain:    "atedra.com",
		IpAddress: "54.182.2.31",
	},
	&fronted.Masquerade{
		Domain:    "atlassian.com",
		IpAddress: "205.251.253.135",
	},
	&fronted.Masquerade{
		Domain:    "atlassian.com",
		IpAddress: "216.137.33.114",
	},
	&fronted.Masquerade{
		Domain:    "auctions.com.au",
		IpAddress: "54.182.2.61",
	},
	&fronted.Masquerade{
		Domain:    "auctions.com.au",
		IpAddress: "54.239.130.153",
	},
	&fronted.Masquerade{
		Domain:    "automatic.com",
		IpAddress: "216.137.33.234",
	},
	&fronted.Masquerade{
		Domain:    "autoweb.com",
		IpAddress: "54.182.0.208",
	},
	&fronted.Masquerade{
		Domain:    "autoweb.com",
		IpAddress: "54.182.0.209",
	},
	&fronted.Masquerade{
		Domain:    "autoweb.com",
		IpAddress: "205.251.253.42",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "204.246.164.46",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "52.84.2.182",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "54.182.1.38",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "54.182.2.196",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "54.182.0.28",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "54.182.0.202",
	},
	&fronted.Masquerade{
		Domain:    "awsapps.com",
		IpAddress: "204.246.164.117",
	},
	&fronted.Masquerade{
		Domain:    "axonify.com",
		IpAddress: "54.182.0.43",
	},
	&fronted.Masquerade{
		Domain:    "babator.com",
		IpAddress: "205.251.253.14",
	},
	&fronted.Masquerade{
		Domain:    "babator.com",
		IpAddress: "54.182.0.106",
	},
	&fronted.Masquerade{
		Domain:    "bam-x.com",
		IpAddress: "54.182.1.120",
	},
	&fronted.Masquerade{
		Domain:    "barbour-abi.com",
		IpAddress: "54.182.1.250",
	},
	&fronted.Masquerade{
		Domain:    "bazaarvoice.com",
		IpAddress: "54.182.1.181",
	},
	&fronted.Masquerade{
		Domain:    "bazaarvoice.com",
		IpAddress: "204.246.164.145",
	},
	&fronted.Masquerade{
		Domain:    "bazaarvoice.com",
		IpAddress: "216.137.33.16",
	},
	&fronted.Masquerade{
		Domain:    "bazaarvoice.com",
		IpAddress: "54.239.130.97",
	},
	&fronted.Masquerade{
		Domain:    "bcash.com.br",
		IpAddress: "205.251.253.65",
	},
	&fronted.Masquerade{
		Domain:    "beautyheroes.fr",
		IpAddress: "54.239.130.101",
	},
	&fronted.Masquerade{
		Domain:    "behancemanage.com",
		IpAddress: "54.182.0.102",
	},
	&fronted.Masquerade{
		Domain:    "belrondev.com",
		IpAddress: "54.182.1.87",
	},
	&fronted.Masquerade{
		Domain:    "beta.shopcurbside.com",
		IpAddress: "54.182.1.67",
	},
	&fronted.Masquerade{
		Domain:    "beta.shopcurbside.com",
		IpAddress: "205.251.253.85",
	},
	&fronted.Masquerade{
		Domain:    "bethsoft.com",
		IpAddress: "205.251.253.233",
	},
	&fronted.Masquerade{
		Domain:    "bethsoft.com",
		IpAddress: "54.182.1.129",
	},
	&fronted.Masquerade{
		Domain:    "bikebandit-images.com",
		IpAddress: "205.251.253.119",
	},
	&fronted.Masquerade{
		Domain:    "bikini.com",
		IpAddress: "54.182.1.58",
	},
	&fronted.Masquerade{
		Domain:    "billygraham.org",
		IpAddress: "54.182.0.89",
	},
	&fronted.Masquerade{
		Domain:    "blackfriday.com",
		IpAddress: "205.251.253.64",
	},
	&fronted.Masquerade{
		Domain:    "blackfriday.com",
		IpAddress: "54.239.130.98",
	},
	&fronted.Masquerade{
		Domain:    "blackfridaysale.at",
		IpAddress: "216.137.33.106",
	},
	&fronted.Masquerade{
		Domain:    "blackfridaysale.at",
		IpAddress: "54.182.0.87",
	},
	&fronted.Masquerade{
		Domain:    "blackfridaysale.de",
		IpAddress: "54.182.1.12",
	},
	&fronted.Masquerade{
		Domain:    "blackfridaysale.de",
		IpAddress: "204.246.164.185",
	},
	&fronted.Masquerade{
		Domain:    "blog.physi.rocks",
		IpAddress: "54.182.0.148",
	},
	&fronted.Masquerade{
		Domain:    "bluefinlabs.com",
		IpAddress: "205.251.253.99",
	},
	&fronted.Masquerade{
		Domain:    "bluefinlabs.com",
		IpAddress: "54.239.130.137",
	},
	&fronted.Masquerade{
		Domain:    "booking.airportshuttles.com",
		IpAddress: "54.182.0.77",
	},
	&fronted.Masquerade{
		Domain:    "bounceexchange.com",
		IpAddress: "54.182.1.228",
	},
	&fronted.Masquerade{
		Domain:    "bounceexchange.com",
		IpAddress: "204.246.164.23",
	},
	&fronted.Masquerade{
		Domain:    "boundless.com",
		IpAddress: "54.182.0.130",
	},
	&fronted.Masquerade{
		Domain:    "brainquakegames-dev.com",
		IpAddress: "54.239.130.105",
	},
	&fronted.Masquerade{
		Domain:    "brandmovers.co",
		IpAddress: "54.182.1.144",
	},
	&fronted.Masquerade{
		Domain:    "brcdn.com",
		IpAddress: "205.251.253.243",
	},
	&fronted.Masquerade{
		Domain:    "brickworksoftware.com",
		IpAddress: "54.182.2.102",
	},
	&fronted.Masquerade{
		Domain:    "brickworksoftware.com",
		IpAddress: "216.137.33.164",
	},
	&fronted.Masquerade{
		Domain:    "bscdn.net",
		IpAddress: "54.182.1.243",
	},
	&fronted.Masquerade{
		Domain:    "bscdn.net",
		IpAddress: "205.251.253.61",
	},
	&fronted.Masquerade{
		Domain:    "bttrack.com",
		IpAddress: "54.239.130.151",
	},
	&fronted.Masquerade{
		Domain:    "bttrack.com",
		IpAddress: "54.182.0.22",
	},
	&fronted.Masquerade{
		Domain:    "buildbucket.org",
		IpAddress: "54.182.1.180",
	},
	&fronted.Masquerade{
		Domain:    "buildbucket.org",
		IpAddress: "54.239.130.207",
	},
	&fronted.Masquerade{
		Domain:    "bundle.media",
		IpAddress: "205.251.253.112",
	},
	&fronted.Masquerade{
		Domain:    "bundles.bittorrent.com",
		IpAddress: "54.239.130.53",
	},
	&fronted.Masquerade{
		Domain:    "buuteeq.com",
		IpAddress: "54.182.0.110",
	},
	&fronted.Masquerade{
		Domain:    "bysymphony.com",
		IpAddress: "54.182.1.188",
	},
	&fronted.Masquerade{
		Domain:    "c.amazon-adsystem.com",
		IpAddress: "54.182.2.101",
	},
	&fronted.Masquerade{
		Domain:    "c.nelly.com",
		IpAddress: "216.137.33.52",
	},
	&fronted.Masquerade{
		Domain:    "c.nelly.com",
		IpAddress: "54.239.130.236",
	},
	&fronted.Masquerade{
		Domain:    "ca-conv.jp",
		IpAddress: "54.182.2.84",
	},
	&fronted.Masquerade{
		Domain:    "ca-conv.jp",
		IpAddress: "54.182.1.42",
	},
	&fronted.Masquerade{
		Domain:    "ca-conv.jp",
		IpAddress: "205.251.253.250",
	},
	&fronted.Masquerade{
		Domain:    "cafewell.com",
		IpAddress: "54.182.1.27",
	},
	&fronted.Masquerade{
		Domain:    "cafewell.com",
		IpAddress: "204.246.164.112",
	},
	&fronted.Masquerade{
		Domain:    "callisto.io",
		IpAddress: "54.239.130.131",
	},
	&fronted.Masquerade{
		Domain:    "canaldapeca.com.br",
		IpAddress: "54.182.0.96",
	},
	&fronted.Masquerade{
		Domain:    "capella.edu",
		IpAddress: "54.239.130.40",
	},
	&fronted.Masquerade{
		Domain:    "captora.com",
		IpAddress: "204.246.164.199",
	},
	&fronted.Masquerade{
		Domain:    "captora.com",
		IpAddress: "54.182.2.208",
	},
	&fronted.Masquerade{
		Domain:    "captora.com",
		IpAddress: "54.182.1.11",
	},
	&fronted.Masquerade{
		Domain:    "cardgames.io",
		IpAddress: "54.182.0.254",
	},
	&fronted.Masquerade{
		Domain:    "careem.com",
		IpAddress: "54.239.130.213",
	},
	&fronted.Masquerade{
		Domain:    "carglass.com",
		IpAddress: "54.182.1.93",
	},
	&fronted.Masquerade{
		Domain:    "casacasino.com",
		IpAddress: "54.182.0.231",
	},
	&fronted.Masquerade{
		Domain:    "ccctcportal.org",
		IpAddress: "54.182.1.60",
	},
	&fronted.Masquerade{
		Domain:    "cdn-payscale.com",
		IpAddress: "54.182.1.244",
	},
	&fronted.Masquerade{
		Domain:    "cdn-recruiter-image.theladders.net",
		IpAddress: "54.182.0.29",
	},
	&fronted.Masquerade{
		Domain:    "cdn.active-robots.com",
		IpAddress: "54.182.0.248",
	},
	&fronted.Masquerade{
		Domain:    "cdn.amazonblogs.com",
		IpAddress: "54.182.2.44",
	},
	&fronted.Masquerade{
		Domain:    "cdn.bswift.com",
		IpAddress: "216.137.33.159",
	},
	&fronted.Masquerade{
		Domain:    "cdn.bswiftqa.com",
		IpAddress: "54.182.1.22",
	},
	&fronted.Masquerade{
		Domain:    "cdn.charizero.appget.com",
		IpAddress: "54.239.130.178",
	},
	&fronted.Masquerade{
		Domain:    "cdn.choremonster.com",
		IpAddress: "54.239.130.183",
	},
	&fronted.Masquerade{
		Domain:    "cdn.concordnow.com",
		IpAddress: "54.182.1.18",
	},
	&fronted.Masquerade{
		Domain:    "cdn.d2gstores.com",
		IpAddress: "54.239.130.167",
	},
	&fronted.Masquerade{
		Domain:    "cdn.displays2go.com",
		IpAddress: "205.251.253.195",
	},
	&fronted.Masquerade{
		Domain:    "cdn.displays2go.com",
		IpAddress: "216.137.33.238",
	},
	&fronted.Masquerade{
		Domain:    "cdn.evergage.com",
		IpAddress: "54.239.130.224",
	},
	&fronted.Masquerade{
		Domain:    "cdn.geocomply.com",
		IpAddress: "54.182.0.216",
	},
	&fronted.Masquerade{
		Domain:    "cdn.globalhealingcenter.com",
		IpAddress: "54.182.0.86",
	},
	&fronted.Masquerade{
		Domain:    "cdn.heapanalytics.com",
		IpAddress: "54.182.1.191",
	},
	&fronted.Masquerade{
		Domain:    "cdn.heapanalytics.com",
		IpAddress: "205.251.253.11",
	},
	&fronted.Masquerade{
		Domain:    "cdn.integration.viber.com",
		IpAddress: "205.251.253.232",
	},
	&fronted.Masquerade{
		Domain:    "cdn.integration.viber.com",
		IpAddress: "54.182.0.8",
	},
	&fronted.Masquerade{
		Domain:    "cdn.livefyre.com",
		IpAddress: "204.246.164.31",
	},
	&fronted.Masquerade{
		Domain:    "cdn.medallia.com",
		IpAddress: "205.251.253.10",
	},
	&fronted.Masquerade{
		Domain:    "cdn.medallia.com",
		IpAddress: "54.182.1.19",
	},
	&fronted.Masquerade{
		Domain:    "cdn.mozilla.net",
		IpAddress: "54.239.130.235",
	},
	&fronted.Masquerade{
		Domain:    "cdn.mozilla.net",
		IpAddress: "54.182.1.103",
	},
	&fronted.Masquerade{
		Domain:    "cdn.mozilla.net",
		IpAddress: "54.182.1.207",
	},
	&fronted.Masquerade{
		Domain:    "cdn.otherlevels.com",
		IpAddress: "216.137.33.211",
	},
	&fronted.Masquerade{
		Domain:    "cdn.otherlevels.com",
		IpAddress: "54.182.0.222",
	},
	&fronted.Masquerade{
		Domain:    "cdn.passporthealthglobal.com",
		IpAddress: "205.251.253.164",
	},
	&fronted.Masquerade{
		Domain:    "cdn.passporthealthglobal.com",
		IpAddress: "204.246.164.232",
	},
	&fronted.Masquerade{
		Domain:    "cdn.passporthealthglobal.com",
		IpAddress: "54.182.1.187",
	},
	&fronted.Masquerade{
		Domain:    "cdn.passporthealthusa.com",
		IpAddress: "205.251.253.207",
	},
	&fronted.Masquerade{
		Domain:    "cdn.passporthealthusa.com",
		IpAddress: "54.182.0.58",
	},
	&fronted.Masquerade{
		Domain:    "cdn.pc-odm.igware.net",
		IpAddress: "54.182.1.153",
	},
	&fronted.Masquerade{
		Domain:    "cdn.pc-odm.igware.net",
		IpAddress: "205.251.253.214",
	},
	&fronted.Masquerade{
		Domain:    "cdn.shptrn.com",
		IpAddress: "216.137.33.99",
	},
	&fronted.Masquerade{
		Domain:    "cdnmedia.advent.com",
		IpAddress: "205.251.253.224",
	},
	&fronted.Masquerade{
		Domain:    "cdnspstr.com",
		IpAddress: "54.239.130.89",
	},
	&fronted.Masquerade{
		Domain:    "cdnz.bib.barclays.com",
		IpAddress: "54.182.1.132",
	},
	&fronted.Masquerade{
		Domain:    "cev.ibiztb.com",
		IpAddress: "54.182.0.182",
	},
	&fronted.Masquerade{
		Domain:    "cf.dropboxpayments.com",
		IpAddress: "216.137.33.36",
	},
	&fronted.Masquerade{
		Domain:    "cf.dropboxpayments.com",
		IpAddress: "205.251.253.97",
	},
	&fronted.Masquerade{
		Domain:    "channeladvisor.com",
		IpAddress: "54.239.130.185",
	},
	&fronted.Masquerade{
		Domain:    "charmingcharlie.com",
		IpAddress: "54.182.2.50",
	},
	&fronted.Masquerade{
		Domain:    "chemistdirect.co.uk",
		IpAddress: "216.137.33.160",
	},
	&fronted.Masquerade{
		Domain:    "chemistdirect.co.uk",
		IpAddress: "54.182.0.201",
	},
	&fronted.Masquerade{
		Domain:    "ciggws.net",
		IpAddress: "205.251.253.51",
	},
	&fronted.Masquerade{
		Domain:    "citifyd.com",
		IpAddress: "54.182.0.17",
	},
	&fronted.Masquerade{
		Domain:    "clearancejobs.com",
		IpAddress: "54.239.130.222",
	},
	&fronted.Masquerade{
		Domain:    "clearslide.com",
		IpAddress: "54.182.1.98",
	},
	&fronted.Masquerade{
		Domain:    "clef.io",
		IpAddress: "216.137.33.12",
	},
	&fronted.Masquerade{
		Domain:    "clef.io",
		IpAddress: "54.182.0.53",
	},
	&fronted.Masquerade{
		Domain:    "client-notifications.lookout.com",
		IpAddress: "54.182.2.231",
	},
	&fronted.Masquerade{
		Domain:    "clients.amazonworkspaces.com",
		IpAddress: "216.137.33.26",
	},
	&fronted.Masquerade{
		Domain:    "clients.amazonworkspaces.com",
		IpAddress: "54.192.2.30",
	},
	&fronted.Masquerade{
		Domain:    "clientupdates.dropboxstatic.com",
		IpAddress: "54.182.1.121",
	},
	&fronted.Masquerade{
		Domain:    "climate.com",
		IpAddress: "54.182.1.254",
	},
	&fronted.Masquerade{
		Domain:    "climate.com",
		IpAddress: "204.246.164.100",
	},
	&fronted.Masquerade{
		Domain:    "cloud.sailpoint.com",
		IpAddress: "54.182.2.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.20",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.116",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.151",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.98",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.94",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.130",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.31",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.21",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.113",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.143",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.120",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.16",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.139",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.15",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.69",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.133",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.73",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.134",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.146",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.41",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.25",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.36",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.13",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.54",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.10",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.18",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.38",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.22",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.50",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.32",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.92",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.23",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.37",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.75",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.52",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.26",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.63",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.14",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.61",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.24",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.72",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.48",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.64",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.44",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.60",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.39",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.58",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.97",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.180",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.86",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.84",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.164",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.65",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.28",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.7",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.101",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.74",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.183",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.79",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.66",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.17",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.55",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.105",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.85",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.106",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.83",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.43",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.90",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.112",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.102",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.158",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.100",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.128",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.19",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.87",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.96",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.169",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.157",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.82",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.168",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.142",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.77",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.165",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.184",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.30",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.34",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.144",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.182",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.167",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.163",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.137",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.27",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.91",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.162",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.122",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.176",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.49",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.175",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.159",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.170",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.177",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.174",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.179",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.88",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.125",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.181",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.178",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.148",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.141",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.171",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.103",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.156",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.166",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.45",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.173",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.81",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.147",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.149",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.121",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.53",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.59",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.78",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.70",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.62",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.138",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.93",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.185",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.188",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.187",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.186",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.190",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.189",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.172",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.124",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.89",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.99",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.68",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.161",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.154",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.108",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.155",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.191",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.6",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.7",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.8",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.136",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.153",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.192",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.195",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.194",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.193",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.9",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.196",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.197",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.198",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.10",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.12",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.199",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.200",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.13",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.14",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.201",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.203",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.204",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.16",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.15",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.205",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.18",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.206",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.207",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.19",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.20",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.208",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.22",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.210",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.178",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.179",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.180",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.181",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.182",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.183",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.184",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.185",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.186",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.187",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.189",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.190",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.188",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.191",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.192",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.193",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.194",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.195",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.196",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.197",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.200",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.201",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.202",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.204",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.205",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.203",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.206",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.207",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.208",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.209",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.210",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.211",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.213",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.212",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.214",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.215",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.216",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.217",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.219",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.218",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.220",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.221",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.222",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.223",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.224",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.225",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.226",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.227",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.228",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.229",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.230",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.232",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.233",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.234",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.235",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.236",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.237",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.238",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.239",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.240",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.241",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.243",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.242",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.245",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.244",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.246",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.247",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.2",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.3",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.248",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.249",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.250",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.6",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.251",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.252",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.7",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.253",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.8",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.254",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.9",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.10",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.12",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.13",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.14",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.15",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.17",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.16",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.18",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.19",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.20",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.21",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.22",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.24",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.23",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.25",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.26",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.27",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.28",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.29",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.30",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.31",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.32",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.33",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.36",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.34",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.35",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.38",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.37",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.41",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.39",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.42",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.43",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.44",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.45",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.48",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.49",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.50",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.52",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.33.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.53",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.54",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.55",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.56",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.57",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.58",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.59",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.60",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.61",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.62",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.63",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.64",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.65",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.66",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.67",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.69",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.68",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.70",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.71",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.72",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.75",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.76",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.74",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.73",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.78",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.79",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.77",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.82",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.81",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.83",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.84",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.85",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.86",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.87",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.89",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.88",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.90",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.91",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.92",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.93",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.94",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.95",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.96",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.97",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.98",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.99",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.100",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.101",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.102",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.103",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.104",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.105",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.106",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.107",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.108",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.110",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.109",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.111",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.112",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.115",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.113",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.114",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.116",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.117",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.118",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.120",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.121",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.119",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.122",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.123",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.124",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.125",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.128",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.127",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.126",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.129",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.130",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.133",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.134",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.136",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.135",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.137",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.139",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.138",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.140",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.141",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.142",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.144",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.143",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.147",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.146",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.145",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.150",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.148",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.149",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.151",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.153",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.154",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "205.251.253.150",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.152",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.155",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.157",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.156",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.158",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.160",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.161",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "205.251.253.158",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.163",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.159",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.162",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.164",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.165",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.166",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.167",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.170",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.168",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.169",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.171",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.172",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.175",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.176",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.173",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.174",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.177",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.178",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.180",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.179",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.181",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.182",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.185",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.184",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.183",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.186",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.187",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.188",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.189",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.190",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.191",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.192",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.193",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.194",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.195",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.196",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.197",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.198",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.199",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.200",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.201",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.202",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.203",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.204",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.205",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.206",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.207",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.208",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.209",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.210",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.211",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.213",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.212",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.214",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.215",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.216",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.217",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.218",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.219",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.220",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.221",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.222",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.223",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.224",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.226",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.225",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.228",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.227",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.229",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.230",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.231",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.232",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.233",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.236",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.235",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.234",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.237",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.239",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.238",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.240",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.242",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.241",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.243",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.244",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.246",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.245",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.247",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.249",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.248",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.250",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.251",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.252",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.254",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.129.253",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.2",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.3",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.6",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.7",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.8",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.9",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.10",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.12",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.14",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.13",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.15",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.16",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.17",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.18",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.19",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.20",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.21",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.22",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.23",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.24",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.25",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.26",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.27",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.28",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.30",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.29",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.32",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.31",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.33",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.36",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.34",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.35",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.38",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.37",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.39",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.41",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.42",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.43",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.44",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.45",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.48",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.50",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.49",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.52",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.53",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.54",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.55",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.56",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.57",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.58",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.59",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.60",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.61",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.62",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.63",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.64",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.65",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.68",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.66",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.67",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.69",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.70",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.73",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.71",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.74",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.72",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.75",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.76",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.77",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.78",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.79",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.81",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.82",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.83",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.84",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.85",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.86",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.87",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.88",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.89",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.91",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.92",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.93",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.90",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.94",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.95",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.130.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.96",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.97",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.98",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.99",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.100",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.101",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.102",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.103",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.104",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.106",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.105",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.107",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.108",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.109",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.110",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.111",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.113",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.112",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.115",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.116",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.114",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.117",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.118",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.119",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.120",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.121",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.122",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.125",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.123",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.124",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.127",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.126",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.128",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.129",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.130",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.132",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.133",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.135",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.136",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.137",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.138",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.139",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.140",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.141",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.142",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.143",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.144",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.145",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.146",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.147",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.149",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.148",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.150",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.152",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.153",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.154",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.155",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.151",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.157",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.158",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.156",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.159",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.160",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.161",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.163",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.162",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.164",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.165",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.166",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.167",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.168",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.169",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.170",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.172",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.171",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.130.161",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.175",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.176",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.174",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.173",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.178",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.179",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.177",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.180",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.182",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.181",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.183",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.185",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.184",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.186",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.187",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.189",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.188",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.190",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.192",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.191",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.193",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.194",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.195",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.196",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.197",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.198",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.200",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.201",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.203",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.199",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.204",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.205",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.202",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.206",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.207",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.208",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.211",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.209",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.212",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.210",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.213",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.214",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.215",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.217",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.216",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.218",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.220",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.221",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.219",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.222",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.223",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.225",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.224",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.226",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.227",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.229",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.228",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.230",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.231",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.232",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.233",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.234",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.235",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.236",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.237",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.238",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.38",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.21",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.209",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.211",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.23",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.212",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.24",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.213",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.25",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.26",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.214",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.28",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.29",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.216",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.30",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.217",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.220",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.31",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.222",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.32",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.223",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.33",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.224",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.34",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.35",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.36",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.37",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.225",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.226",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.39",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.228",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.229",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.230",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.41",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.231",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.42",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.43",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.232",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.44",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.233",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.45",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.234",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.235",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.48",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.236",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.237",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.238",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.49",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.239",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.240",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.50",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.241",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.53",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.52",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.243",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.54",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.55",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.244",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.56",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.57",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.246",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.245",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.247",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.58",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.59",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.249",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.60",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.250",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.61",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.62",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.63",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.252",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.64",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.253",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.66",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.254",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.67",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.68",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.69",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.70",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.71",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.72",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.73",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.74",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.75",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.76",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.77",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.78",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.79",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.81",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.82",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.83",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.84",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.85",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.86",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.88",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.89",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.90",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.91",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.92",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.93",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.94",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.96",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.95",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.97",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.98",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.99",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.100",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.101",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.102",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.103",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.104",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.105",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.106",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.107",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.108",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.111",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.110",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.112",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.113",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.114",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.115",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.116",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.117",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.118",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.119",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.120",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.122",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.121",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.123",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.124",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.125",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.126",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.127",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.128",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.129",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.130",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.131",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.132",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.133",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.134",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.136",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.137",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.139",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.140",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.141",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.142",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.143",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.145",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.144",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.146",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.147",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.148",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.149",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.150",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.152",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.151",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.154",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.153",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.155",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.156",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.157",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.158",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.159",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.160",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.162",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.163",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.164",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.165",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.166",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.167",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.168",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.169",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.170",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.172",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.171",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.173",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.175",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.174",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.176",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.177",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.145",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.42",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.126",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.76",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.33",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.111",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.131",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.110",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.29",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.12",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.9",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.8",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.119",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.107",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.117",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.150",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.115",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.123",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.132",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.35",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.95",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.140",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.129",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.114",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.118",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.104",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.6",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "52.84.0.109",
	},
	&fronted.Masquerade{
		Domain:    "cloudfrontdemo.com",
		IpAddress: "54.182.1.166",
	},
	&fronted.Masquerade{
		Domain:    "cloudfrontdemo.com",
		IpAddress: "54.239.130.41",
	},
	&fronted.Masquerade{
		Domain:    "cloudfrontdemo.com",
		IpAddress: "204.246.164.20",
	},
	&fronted.Masquerade{
		Domain:    "cms.veikkaus.fi",
		IpAddress: "54.182.1.224",
	},
	&fronted.Masquerade{
		Domain:    "cnevids.com",
		IpAddress: "54.239.130.7",
	},
	&fronted.Masquerade{
		Domain:    "cnevids.com",
		IpAddress: "216.137.33.169",
	},
	&fronted.Masquerade{
		Domain:    "collage.com",
		IpAddress: "54.182.0.212",
	},
	&fronted.Masquerade{
		Domain:    "collectivehealth.com",
		IpAddress: "205.251.253.234",
	},
	&fronted.Masquerade{
		Domain:    "collectivehealth.com",
		IpAddress: "216.137.33.168",
	},
	&fronted.Masquerade{
		Domain:    "commonfloor.com",
		IpAddress: "216.137.33.68",
	},
	&fronted.Masquerade{
		Domain:    "commonfloor.com",
		IpAddress: "54.182.0.80",
	},
	&fronted.Masquerade{
		Domain:    "commonfloor.com",
		IpAddress: "54.239.130.139",
	},
	&fronted.Masquerade{
		Domain:    "company-target.com",
		IpAddress: "205.251.253.228",
	},
	&fronted.Masquerade{
		Domain:    "company-target.com",
		IpAddress: "54.182.2.16",
	},
	&fronted.Masquerade{
		Domain:    "conferencinghub.com",
		IpAddress: "204.246.164.159",
	},
	&fronted.Masquerade{
		Domain:    "connectwise.com",
		IpAddress: "205.251.253.241",
	},
	&fronted.Masquerade{
		Domain:    "constant.co",
		IpAddress: "54.182.1.116",
	},
	&fronted.Masquerade{
		Domain:    "consumerreportscdn.org",
		IpAddress: "204.246.164.51",
	},
	&fronted.Masquerade{
		Domain:    "consumerreportscdn.org",
		IpAddress: "216.137.33.76",
	},
	&fronted.Masquerade{
		Domain:    "contactatonce.com",
		IpAddress: "205.251.253.161",
	},
	&fronted.Masquerade{
		Domain:    "content.abcmouse.com",
		IpAddress: "204.246.164.60",
	},
	&fronted.Masquerade{
		Domain:    "cookies-app.com",
		IpAddress: "54.182.1.64",
	},
	&fronted.Masquerade{
		Domain:    "coresystems.net",
		IpAddress: "216.137.33.107",
	},
	&fronted.Masquerade{
		Domain:    "couchsurfing.com",
		IpAddress: "54.182.2.207",
	},
	&fronted.Masquerade{
		Domain:    "couchsurfing.org",
		IpAddress: "205.251.253.69",
	},
	&fronted.Masquerade{
		Domain:    "coveritlive.com",
		IpAddress: "54.182.1.101",
	},
	&fronted.Masquerade{
		Domain:    "coveritlive.com",
		IpAddress: "205.251.253.191",
	},
	&fronted.Masquerade{
		Domain:    "cozy.co",
		IpAddress: "54.239.130.136",
	},
	&fronted.Masquerade{
		Domain:    "cpdrndcdn.officedepot.com",
		IpAddress: "54.182.0.235",
	},
	&fronted.Masquerade{
		Domain:    "craftsy.com",
		IpAddress: "54.182.1.211",
	},
	&fronted.Masquerade{
		Domain:    "craftsy.com",
		IpAddress: "204.246.164.43",
	},
	&fronted.Masquerade{
		Domain:    "cran.rstudio.com",
		IpAddress: "54.182.1.76",
	},
	&fronted.Masquerade{
		Domain:    "credibility.com",
		IpAddress: "216.137.33.33",
	},
	&fronted.Masquerade{
		Domain:    "crispadvertising.com",
		IpAddress: "54.182.0.122",
	},
	&fronted.Masquerade{
		Domain:    "crispadvertising.com",
		IpAddress: "54.239.130.125",
	},
	&fronted.Masquerade{
		Domain:    "croooober.com",
		IpAddress: "205.251.253.221",
	},
	&fronted.Masquerade{
		Domain:    "crownpeak.net",
		IpAddress: "54.239.130.205",
	},
	&fronted.Masquerade{
		Domain:    "crownpeak.net",
		IpAddress: "54.182.0.163",
	},
	&fronted.Masquerade{
		Domain:    "crownpeak.net",
		IpAddress: "216.137.33.44",
	},
	&fronted.Masquerade{
		Domain:    "cubics.co",
		IpAddress: "54.182.2.111",
	},
	&fronted.Masquerade{
		Domain:    "custom-origin.cloudfront-test.net",
		IpAddress: "54.240.130.134",
	},
	&fronted.Masquerade{
		Domain:    "custom-origin.cloudfront-test.net",
		IpAddress: "54.240.129.131",
	},
	&fronted.Masquerade{
		Domain:    "d1ami0ppw26nmn.cloudfront.net",
		IpAddress: "216.137.33.24",
	},
	&fronted.Masquerade{
		Domain:    "d1jwpcr0q4pcq0.cloudfront.net",
		IpAddress: "205.251.253.216",
	},
	&fronted.Masquerade{
		Domain:    "d1rucrevwzgc5t.cloudfront.net",
		IpAddress: "204.246.164.253",
	},
	&fronted.Masquerade{
		Domain:    "d1rucrevwzgc5t.cloudfront.net",
		IpAddress: "54.182.0.104",
	},
	&fronted.Masquerade{
		Domain:    "d1rucrevwzgc5t.cloudfront.net",
		IpAddress: "54.239.130.180",
	},
	&fronted.Masquerade{
		Domain:    "d1vipartqpsj5t.cloudfront.net",
		IpAddress: "54.182.1.113",
	},
	&fronted.Masquerade{
		Domain:    "danestreet.com",
		IpAddress: "204.246.164.128",
	},
	&fronted.Masquerade{
		Domain:    "dapulse.com",
		IpAddress: "54.239.130.120",
	},
	&fronted.Masquerade{
		Domain:    "dashboard.gregmcconnel.net",
		IpAddress: "54.182.0.98",
	},
	&fronted.Masquerade{
		Domain:    "data.annalect.com",
		IpAddress: "54.182.1.70",
	},
	&fronted.Masquerade{
		Domain:    "data.annalect.com",
		IpAddress: "54.239.130.44",
	},
	&fronted.Masquerade{
		Domain:    "data.plus.bandainamcoid.com",
		IpAddress: "216.137.33.147",
	},
	&fronted.Masquerade{
		Domain:    "data.plus.bandainamcoid.com",
		IpAddress: "54.182.1.95",
	},
	&fronted.Masquerade{
		Domain:    "datafiniti.co",
		IpAddress: "204.246.164.206",
	},
	&fronted.Masquerade{
		Domain:    "datalens.here.com",
		IpAddress: "54.182.2.145",
	},
	&fronted.Masquerade{
		Domain:    "ddragon.leagueoflegends.com",
		IpAddress: "54.182.1.220",
	},
	&fronted.Masquerade{
		Domain:    "democrats.org",
		IpAddress: "54.182.1.115",
	},
	&fronted.Masquerade{
		Domain:    "democrats.org",
		IpAddress: "204.246.164.177",
	},
	&fronted.Masquerade{
		Domain:    "democrats.org",
		IpAddress: "216.137.33.170",
	},
	&fronted.Masquerade{
		Domain:    "democrats.org",
		IpAddress: "54.182.2.233",
	},
	&fronted.Masquerade{
		Domain:    "dev-be-aws.net",
		IpAddress: "216.137.33.65",
	},
	&fronted.Masquerade{
		Domain:    "dev-utopia.com",
		IpAddress: "205.251.251.147",
	},
	&fronted.Masquerade{
		Domain:    "dev-utopia.com",
		IpAddress: "54.182.0.123",
	},
	&fronted.Masquerade{
		Domain:    "dev.public.supportsite.a.intuit.com",
		IpAddress: "205.251.253.189",
	},
	&fronted.Masquerade{
		Domain:    "dev1.whispir.net",
		IpAddress: "205.251.253.249",
	},
	&fronted.Masquerade{
		Domain:    "devwowcher.co.uk",
		IpAddress: "204.246.164.180",
	},
	&fronted.Masquerade{
		Domain:    "discoverhawaiitours.com",
		IpAddress: "54.182.1.28",
	},
	&fronted.Masquerade{
		Domain:    "doctorbase.com",
		IpAddress: "54.239.130.17",
	},
	&fronted.Masquerade{
		Domain:    "dolphin-browser.com",
		IpAddress: "54.182.0.214",
	},
	&fronted.Masquerade{
		Domain:    "dolphin-browser.com",
		IpAddress: "216.137.33.79",
	},
	&fronted.Masquerade{
		Domain:    "domain.com.au",
		IpAddress: "205.251.251.125",
	},
	&fronted.Masquerade{
		Domain:    "domdex.com",
		IpAddress: "54.239.130.52",
	},
	&fronted.Masquerade{
		Domain:    "dots.here.com",
		IpAddress: "216.137.33.126",
	},
	&fronted.Masquerade{
		Domain:    "download.epicgames.com",
		IpAddress: "54.239.130.142",
	},
	&fronted.Masquerade{
		Domain:    "dpl.unicornmedia.com",
		IpAddress: "54.182.1.213",
	},
	&fronted.Masquerade{
		Domain:    "dreambox.com",
		IpAddress: "205.251.253.225",
	},
	&fronted.Masquerade{
		Domain:    "dropcam.com",
		IpAddress: "54.182.2.114",
	},
	&fronted.Masquerade{
		Domain:    "dwell.com",
		IpAddress: "54.182.2.51",
	},
	&fronted.Masquerade{
		Domain:    "ehealth.org.ng",
		IpAddress: "216.137.33.193",
	},
	&fronted.Masquerade{
		Domain:    "ehealth.org.ng",
		IpAddress: "204.246.164.58",
	},
	&fronted.Masquerade{
		Domain:    "elo7.com.br",
		IpAddress: "54.239.130.43",
	},
	&fronted.Masquerade{
		Domain:    "elo7.com.br",
		IpAddress: "216.137.33.91",
	},
	&fronted.Masquerade{
		Domain:    "elss.me",
		IpAddress: "54.239.130.109",
	},
	&fronted.Masquerade{
		Domain:    "enetscores.com",
		IpAddress: "205.251.253.102",
	},
	&fronted.Masquerade{
		Domain:    "enetscores.com",
		IpAddress: "204.246.164.78",
	},
	&fronted.Masquerade{
		Domain:    "enetscores.com",
		IpAddress: "54.182.0.41",
	},
	&fronted.Masquerade{
		Domain:    "engage.io",
		IpAddress: "205.251.253.208",
	},
	&fronted.Masquerade{
		Domain:    "engage.io",
		IpAddress: "204.246.164.251",
	},
	&fronted.Masquerade{
		Domain:    "engage.io",
		IpAddress: "54.182.0.7",
	},
	&fronted.Masquerade{
		Domain:    "enish-games.com",
		IpAddress: "54.239.130.195",
	},
	&fronted.Masquerade{
		Domain:    "enterprise.weatherbug.com",
		IpAddress: "54.182.0.91",
	},
	&fronted.Masquerade{
		Domain:    "epicgames.com",
		IpAddress: "205.251.253.231",
	},
	&fronted.Masquerade{
		Domain:    "esparklearning.com",
		IpAddress: "54.182.1.52",
	},
	&fronted.Masquerade{
		Domain:    "euroinvestor.com",
		IpAddress: "216.137.33.45",
	},
	&fronted.Masquerade{
		Domain:    "eventable.com",
		IpAddress: "54.239.130.168",
	},
	&fronted.Masquerade{
		Domain:    "evident.io",
		IpAddress: "216.137.33.253",
	},
	&fronted.Masquerade{
		Domain:    "eyes.nasa.gov",
		IpAddress: "204.246.164.122",
	},
	&fronted.Masquerade{
		Domain:    "fancred.org",
		IpAddress: "204.246.164.165",
	},
	&fronted.Masquerade{
		Domain:    "fanduel.com",
		IpAddress: "204.246.164.53",
	},
	&fronted.Masquerade{
		Domain:    "fanduel.com",
		IpAddress: "216.137.33.10",
	},
	&fronted.Masquerade{
		Domain:    "fanduel.com",
		IpAddress: "54.239.130.99",
	},
	&fronted.Masquerade{
		Domain:    "fed-bam.com",
		IpAddress: "54.239.130.39",
	},
	&fronted.Masquerade{
		Domain:    "fifaconnect.org",
		IpAddress: "204.246.164.98",
	},
	&fronted.Masquerade{
		Domain:    "fifaconnect.org",
		IpAddress: "54.182.0.30",
	},
	&fronted.Masquerade{
		Domain:    "fifaconnect.org",
		IpAddress: "205.251.253.33",
	},
	&fronted.Masquerade{
		Domain:    "files.accessiq.sailpoint.com",
		IpAddress: "54.239.130.102",
	},
	&fronted.Masquerade{
		Domain:    "first-utility.com",
		IpAddress: "204.246.164.223",
	},
	&fronted.Masquerade{
		Domain:    "firstrade.com",
		IpAddress: "205.251.253.39",
	},
	&fronted.Masquerade{
		Domain:    "fisherpaykel.com",
		IpAddress: "54.182.2.183",
	},
	&fronted.Masquerade{
		Domain:    "fisherpaykel.com",
		IpAddress: "205.251.253.133",
	},
	&fronted.Masquerade{
		Domain:    "fitchlearning.com",
		IpAddress: "54.182.0.197",
	},
	&fronted.Masquerade{
		Domain:    "fitmoo.com",
		IpAddress: "216.137.33.138",
	},
	&fronted.Masquerade{
		Domain:    "flamingo.gomobile.jp",
		IpAddress: "54.182.1.141",
	},
	&fronted.Masquerade{
		Domain:    "flipagram.com",
		IpAddress: "54.182.2.206",
	},
	&fronted.Masquerade{
		Domain:    "flipboard.com",
		IpAddress: "205.251.253.222",
	},
	&fronted.Masquerade{
		Domain:    "flipboard.com",
		IpAddress: "204.246.164.103",
	},
	&fronted.Masquerade{
		Domain:    "flipboard.com",
		IpAddress: "54.182.1.96",
	},
	&fronted.Masquerade{
		Domain:    "flipboard.com",
		IpAddress: "54.239.130.104",
	},
	&fronted.Masquerade{
		Domain:    "foodlogiq.com",
		IpAddress: "205.251.253.74",
	},
	&fronted.Masquerade{
		Domain:    "foodlogiq.com",
		IpAddress: "204.246.164.200",
	},
	&fronted.Masquerade{
		Domain:    "framework-gb-ssl.cdn.gob.mx",
		IpAddress: "54.239.130.232",
	},
	&fronted.Masquerade{
		Domain:    "frequency.com",
		IpAddress: "54.182.0.82",
	},
	&fronted.Masquerade{
		Domain:    "freshdesk.com",
		IpAddress: "54.239.130.172",
	},
	&fronted.Masquerade{
		Domain:    "freshdesk.com",
		IpAddress: "54.182.0.215",
	},
	&fronted.Masquerade{
		Domain:    "freshdesk.com",
		IpAddress: "205.251.253.5",
	},
	&fronted.Masquerade{
		Domain:    "freshdesk.com",
		IpAddress: "54.239.130.149",
	},
	&fronted.Masquerade{
		Domain:    "front.xoedge.com",
		IpAddress: "54.182.2.60",
	},
	&fronted.Masquerade{
		Domain:    "front.xoedge.com",
		IpAddress: "205.251.253.8",
	},
	&fronted.Masquerade{
		Domain:    "ftp.mozilla.org",
		IpAddress: "216.137.33.186",
	},
	&fronted.Masquerade{
		Domain:    "fullscreen.net",
		IpAddress: "54.182.0.226",
	},
	&fronted.Masquerade{
		Domain:    "fusion-universal.com",
		IpAddress: "204.246.169.16",
	},
	&fronted.Masquerade{
		Domain:    "futurelearn.com",
		IpAddress: "54.182.2.36",
	},
	&fronted.Masquerade{
		Domain:    "gastecnologia.com.br",
		IpAddress: "216.137.33.163",
	},
	&fronted.Masquerade{
		Domain:    "gastecnologia.com.br",
		IpAddress: "54.182.2.57",
	},
	&fronted.Masquerade{
		Domain:    "gastecnologia.com.br",
		IpAddress: "205.251.253.40",
	},
	&fronted.Masquerade{
		Domain:    "get.com",
		IpAddress: "204.246.164.158",
	},
	&fronted.Masquerade{
		Domain:    "getdata.preprod.intuitcdn.net",
		IpAddress: "205.251.253.100",
	},
	&fronted.Masquerade{
		Domain:    "gimmegimme.it",
		IpAddress: "205.251.253.137",
	},
	&fronted.Masquerade{
		Domain:    "glide.me",
		IpAddress: "216.137.33.29",
	},
	&fronted.Masquerade{
		Domain:    "globalmeet.com",
		IpAddress: "54.182.0.185",
	},
	&fronted.Masquerade{
		Domain:    "globalsocialinc.com",
		IpAddress: "54.182.0.55",
	},
	&fronted.Masquerade{
		Domain:    "go.video2brain.com",
		IpAddress: "54.182.0.196",
	},
	&fronted.Masquerade{
		Domain:    "goinstant.net",
		IpAddress: "205.251.253.88",
	},
	&fronted.Masquerade{
		Domain:    "goinstant.net",
		IpAddress: "54.182.2.136",
	},
	&fronted.Masquerade{
		Domain:    "goinstant.org",
		IpAddress: "205.251.253.173",
	},
	&fronted.Masquerade{
		Domain:    "goinstant.org",
		IpAddress: "54.182.2.77",
	},
	&fronted.Masquerade{
		Domain:    "goldspotmedia.com",
		IpAddress: "54.182.0.121",
	},
	&fronted.Masquerade{
		Domain:    "goorulearning.org",
		IpAddress: "54.182.0.238",
	},
	&fronted.Masquerade{
		Domain:    "gowayin.com",
		IpAddress: "54.182.1.198",
	},
	&fronted.Masquerade{
		Domain:    "gp-static.com",
		IpAddress: "205.251.253.101",
	},
	&fronted.Masquerade{
		Domain:    "gp-static.com",
		IpAddress: "54.239.130.163",
	},
	&fronted.Masquerade{
		Domain:    "gp-static.com",
		IpAddress: "205.251.253.93",
	},
	&fronted.Masquerade{
		Domain:    "gp-static.com",
		IpAddress: "54.182.2.178",
	},
	&fronted.Masquerade{
		Domain:    "gp-static.com",
		IpAddress: "54.182.0.137",
	},
	&fronted.Masquerade{
		Domain:    "gpushtest.gtesting.nl",
		IpAddress: "54.239.130.146",
	},
	&fronted.Masquerade{
		Domain:    "greatnationseat.org",
		IpAddress: "54.182.0.116",
	},
	&fronted.Masquerade{
		Domain:    "groupme.com",
		IpAddress: "54.239.130.32",
	},
	&fronted.Masquerade{
		Domain:    "groupme.com",
		IpAddress: "204.246.164.137",
	},
	&fronted.Masquerade{
		Domain:    "gyft.com",
		IpAddress: "54.182.1.50",
	},
	&fronted.Masquerade{
		Domain:    "gyft.com",
		IpAddress: "54.239.130.92",
	},
	&fronted.Masquerade{
		Domain:    "handoutsrc.gotowebinar.com",
		IpAddress: "54.182.1.235",
	},
	&fronted.Masquerade{
		Domain:    "handoutsrc.gotowebinar.com",
		IpAddress: "52.84.2.196",
	},
	&fronted.Masquerade{
		Domain:    "handoutsstage.gotowebinar.com",
		IpAddress: "54.182.0.162",
	},
	&fronted.Masquerade{
		Domain:    "happify.com",
		IpAddress: "54.239.130.173",
	},
	&fronted.Masquerade{
		Domain:    "harpercollins.co.uk",
		IpAddress: "216.137.33.19",
	},
	&fronted.Masquerade{
		Domain:    "hbonow.com",
		IpAddress: "54.239.130.62",
	},
	&fronted.Masquerade{
		Domain:    "hbonow.com",
		IpAddress: "54.182.2.43",
	},
	&fronted.Masquerade{
		Domain:    "hbonow.com",
		IpAddress: "54.182.2.190",
	},
	&fronted.Masquerade{
		Domain:    "hbonow.com",
		IpAddress: "216.137.33.118",
	},
	&fronted.Masquerade{
		Domain:    "hbonow.com",
		IpAddress: "54.239.130.214",
	},
	&fronted.Masquerade{
		Domain:    "hc1demo.com",
		IpAddress: "54.239.130.82",
	},
	&fronted.Masquerade{
		Domain:    "headspin.io",
		IpAddress: "205.251.251.7",
	},
	&fronted.Masquerade{
		Domain:    "headspin.io",
		IpAddress: "54.182.2.25",
	},
	&fronted.Masquerade{
		Domain:    "healthcare.com",
		IpAddress: "54.230.2.241",
	},
	&fronted.Masquerade{
		Domain:    "healthcare.com",
		IpAddress: "54.182.1.81",
	},
	&fronted.Masquerade{
		Domain:    "healthcheck.dropboxstatic.com",
		IpAddress: "54.182.0.213",
	},
	&fronted.Masquerade{
		Domain:    "healthgrades.com",
		IpAddress: "54.182.1.178",
	},
	&fronted.Masquerade{
		Domain:    "healthination.com",
		IpAddress: "54.182.1.49",
	},
	&fronted.Masquerade{
		Domain:    "healthination.com",
		IpAddress: "205.251.253.141",
	},
	&fronted.Masquerade{
		Domain:    "healthtap.com",
		IpAddress: "205.251.253.159",
	},
	&fronted.Masquerade{
		Domain:    "hellocdn.net",
		IpAddress: "54.239.130.55",
	},
	&fronted.Masquerade{
		Domain:    "homepackbuzz.com",
		IpAddress: "54.182.0.108",
	},
	&fronted.Masquerade{
		Domain:    "homepackbuzz.com",
		IpAddress: "54.182.1.201",
	},
	&fronted.Masquerade{
		Domain:    "homepackbuzz.com",
		IpAddress: "205.251.253.210",
	},
	&fronted.Masquerade{
		Domain:    "homes.co.jp",
		IpAddress: "54.239.130.20",
	},
	&fronted.Masquerade{
		Domain:    "homes.co.jp",
		IpAddress: "54.182.0.176",
	},
	&fronted.Masquerade{
		Domain:    "homes.co.jp",
		IpAddress: "204.246.164.16",
	},
	&fronted.Masquerade{
		Domain:    "hoodline.com",
		IpAddress: "216.137.33.94",
	},
	&fronted.Masquerade{
		Domain:    "hopskipdrive.com",
		IpAddress: "205.251.253.196",
	},
	&fronted.Masquerade{
		Domain:    "hopskipdrive.com",
		IpAddress: "54.239.130.230",
	},
	&fronted.Masquerade{
		Domain:    "huddle.com",
		IpAddress: "54.182.2.134",
	},
	&fronted.Masquerade{
		Domain:    "iam-cf-gamma.cloudfront-test.net",
		IpAddress: "54.182.0.132",
	},
	&fronted.Masquerade{
		Domain:    "ibiztb.com",
		IpAddress: "205.251.251.64",
	},
	&fronted.Masquerade{
		Domain:    "ifcdn.com",
		IpAddress: "54.239.130.164",
	},
	&fronted.Masquerade{
		Domain:    "iflix.com",
		IpAddress: "205.251.253.120",
	},
	&fronted.Masquerade{
		Domain:    "iitutw.net",
		IpAddress: "54.182.2.5",
	},
	&fronted.Masquerade{
		Domain:    "iitutw.net",
		IpAddress: "205.251.253.67",
	},
	&fronted.Masquerade{
		Domain:    "iitutw.net",
		IpAddress: "52.84.0.127",
	},
	&fronted.Masquerade{
		Domain:    "image2.coolblue.io",
		IpAddress: "204.246.164.69",
	},
	&fronted.Masquerade{
		Domain:    "images.baunat.com",
		IpAddress: "54.239.130.83",
	},
	&fronted.Masquerade{
		Domain:    "images.insinkerator-worldwide.com",
		IpAddress: "54.182.0.10",
	},
	&fronted.Masquerade{
		Domain:    "imedicare.com",
		IpAddress: "54.182.0.61",
	},
	&fronted.Masquerade{
		Domain:    "imeet.com",
		IpAddress: "54.239.130.175",
	},
	&fronted.Masquerade{
		Domain:    "imeet.se",
		IpAddress: "216.137.33.202",
	},
	&fronted.Masquerade{
		Domain:    "imeet.se",
		IpAddress: "54.182.0.152",
	},
	&fronted.Masquerade{
		Domain:    "imeetbeta.net",
		IpAddress: "54.239.130.86",
	},
	&fronted.Masquerade{
		Domain:    "img.point.auone.jp",
		IpAddress: "54.182.0.31",
	},
	&fronted.Masquerade{
		Domain:    "img.vipme.com",
		IpAddress: "205.251.251.196",
	},
	&fronted.Masquerade{
		Domain:    "img.vipme.com",
		IpAddress: "54.182.0.242",
	},
	&fronted.Masquerade{
		Domain:    "imoji.io",
		IpAddress: "54.182.0.236",
	},
	&fronted.Masquerade{
		Domain:    "infospace.com",
		IpAddress: "54.182.0.75",
	},
	&fronted.Masquerade{
		Domain:    "inkfrog.com",
		IpAddress: "204.246.164.227",
	},
	&fronted.Masquerade{
		Domain:    "inkfrog.com",
		IpAddress: "52.84.2.58",
	},
	&fronted.Masquerade{
		Domain:    "innotas.com",
		IpAddress: "54.182.0.101",
	},
	&fronted.Masquerade{
		Domain:    "innotas.com",
		IpAddress: "205.251.253.63",
	},
	&fronted.Masquerade{
		Domain:    "innotas.com",
		IpAddress: "54.182.0.95",
	},
	&fronted.Masquerade{
		Domain:    "insead.edu",
		IpAddress: "54.239.130.190",
	},
	&fronted.Masquerade{
		Domain:    "insighttimer.com",
		IpAddress: "54.182.1.233",
	},
	&fronted.Masquerade{
		Domain:    "insit.co",
		IpAddress: "54.239.130.106",
	},
	&fronted.Masquerade{
		Domain:    "inspsearchapi.com",
		IpAddress: "205.251.253.253",
	},
	&fronted.Masquerade{
		Domain:    "inspsearchapi.com",
		IpAddress: "54.182.2.89",
	},
	&fronted.Masquerade{
		Domain:    "instaforex.com",
		IpAddress: "204.246.164.55",
	},
	&fronted.Masquerade{
		Domain:    "instaforex.com",
		IpAddress: "54.182.1.88",
	},
	&fronted.Masquerade{
		Domain:    "int-type-b.cctsl.com",
		IpAddress: "54.182.2.166",
	},
	&fronted.Masquerade{
		Domain:    "intercom.io",
		IpAddress: "54.182.0.250",
	},
	&fronted.Masquerade{
		Domain:    "interpolls.com",
		IpAddress: "205.251.253.182",
	},
	&fronted.Masquerade{
		Domain:    "itravel2000.com",
		IpAddress: "205.251.253.89",
	},
	&fronted.Masquerade{
		Domain:    "itravel2000.com",
		IpAddress: "54.182.2.142",
	},
	&fronted.Masquerade{
		Domain:    "itriagehealth.com",
		IpAddress: "205.251.253.192",
	},
	&fronted.Masquerade{
		Domain:    "jawbone.com",
		IpAddress: "54.182.1.227",
	},
	&fronted.Masquerade{
		Domain:    "jawbone.com",
		IpAddress: "216.137.33.34",
	},
	&fronted.Masquerade{
		Domain:    "jawbone.com",
		IpAddress: "54.239.130.132",
	},
	&fronted.Masquerade{
		Domain:    "jazz.co",
		IpAddress: "204.246.164.146",
	},
	&fronted.Masquerade{
		Domain:    "jazz.co",
		IpAddress: "54.182.0.14",
	},
	&fronted.Masquerade{
		Domain:    "jiveapps.com",
		IpAddress: "205.251.253.118",
	},
	&fronted.Masquerade{
		Domain:    "kaltura.com",
		IpAddress: "54.182.0.125",
	},
	&fronted.Masquerade{
		Domain:    "keas.com",
		IpAddress: "54.182.1.150",
	},
	&fronted.Masquerade{
		Domain:    "keas.com",
		IpAddress: "54.239.130.69",
	},
	&fronted.Masquerade{
		Domain:    "kenshoo-lab.com",
		IpAddress: "54.239.130.54",
	},
	&fronted.Masquerade{
		Domain:    "kik.com",
		IpAddress: "54.239.130.165",
	},
	&fronted.Masquerade{
		Domain:    "kinnek.com",
		IpAddress: "216.137.33.7",
	},
	&fronted.Masquerade{
		Domain:    "kinnek.com",
		IpAddress: "54.239.130.27",
	},
	&fronted.Masquerade{
		Domain:    "kinnek.com",
		IpAddress: "54.182.1.107",
	},
	&fronted.Masquerade{
		Domain:    "kobes.co.kr",
		IpAddress: "54.239.130.159",
	},
	&fronted.Masquerade{
		Domain:    "kppgame.com",
		IpAddress: "54.182.0.51",
	},
	&fronted.Masquerade{
		Domain:    "kppgame.com",
		IpAddress: "216.137.33.244",
	},
	&fronted.Masquerade{
		Domain:    "krossover.com",
		IpAddress: "205.251.253.92",
	},
	&fronted.Masquerade{
		Domain:    "krxd.net",
		IpAddress: "54.182.0.184",
	},
	&fronted.Masquerade{
		Domain:    "kyruus.com",
		IpAddress: "205.251.253.12",
	},
	&fronted.Masquerade{
		Domain:    "lab.digitalpublishing.adobe.com",
		IpAddress: "54.182.0.195",
	},
	&fronted.Masquerade{
		Domain:    "labtechsoftware.com",
		IpAddress: "204.246.164.95",
	},
	&fronted.Masquerade{
		Domain:    "lazydays.com",
		IpAddress: "54.182.1.33",
	},
	&fronted.Masquerade{
		Domain:    "leadformix.com",
		IpAddress: "54.182.1.175",
	},
	&fronted.Masquerade{
		Domain:    "learningcenter.com",
		IpAddress: "54.239.130.156",
	},
	&fronted.Masquerade{
		Domain:    "learningcenter.com",
		IpAddress: "205.251.253.131",
	},
	&fronted.Masquerade{
		Domain:    "learningcenter.com",
		IpAddress: "54.239.130.197",
	},
	&fronted.Masquerade{
		Domain:    "lifelock.com",
		IpAddress: "204.246.164.178",
	},
	&fronted.Masquerade{
		Domain:    "listrunnerapp.com",
		IpAddress: "54.182.1.130",
	},
	&fronted.Masquerade{
		Domain:    "litmus.com",
		IpAddress: "54.239.130.194",
	},
	&fronted.Masquerade{
		Domain:    "liveboox.com",
		IpAddress: "216.137.33.64",
	},
	&fronted.Masquerade{
		Domain:    "liveboox.com",
		IpAddress: "54.239.130.95",
	},
	&fronted.Masquerade{
		Domain:    "liveboox.com",
		IpAddress: "54.182.1.83",
	},
	&fronted.Masquerade{
		Domain:    "liveminutes.com",
		IpAddress: "54.182.0.48",
	},
	&fronted.Masquerade{
		Domain:    "locationkit.io",
		IpAddress: "204.246.164.167",
	},
	&fronted.Masquerade{
		Domain:    "lovegold.cn",
		IpAddress: "204.246.164.79",
	},
	&fronted.Masquerade{
		Domain:    "luc.id",
		IpAddress: "205.251.253.169",
	},
	&fronted.Masquerade{
		Domain:    "lyft.com",
		IpAddress: "54.182.1.134",
	},
	&fronted.Masquerade{
		Domain:    "m-ink.etradefinancial.com",
		IpAddress: "54.182.1.105",
	},
	&fronted.Masquerade{
		Domain:    "m.here.com",
		IpAddress: "204.246.169.220",
	},
	&fronted.Masquerade{
		Domain:    "malwarebytes.org",
		IpAddress: "204.246.164.8",
	},
	&fronted.Masquerade{
		Domain:    "malwarebytes.org",
		IpAddress: "54.182.1.143",
	},
	&fronted.Masquerade{
		Domain:    "mangahigh.cn",
		IpAddress: "54.239.130.48",
	},
	&fronted.Masquerade{
		Domain:    "mangahigh.cn",
		IpAddress: "216.137.33.179",
	},
	&fronted.Masquerade{
		Domain:    "maplarge.com",
		IpAddress: "216.137.33.220",
	},
	&fronted.Masquerade{
		Domain:    "maplarge.com",
		IpAddress: "54.182.0.156",
	},
	&fronted.Masquerade{
		Domain:    "massrelevance.com",
		IpAddress: "54.239.130.57",
	},
	&fronted.Masquerade{
		Domain:    "mbamupdates.com",
		IpAddress: "216.137.33.222",
	},
	&fronted.Masquerade{
		Domain:    "mebelkart.com",
		IpAddress: "216.137.33.172",
	},
	&fronted.Masquerade{
		Domain:    "mediagraph.com",
		IpAddress: "54.182.1.62",
	},
	&fronted.Masquerade{
		Domain:    "micpn.com",
		IpAddress: "54.182.0.203",
	},
	&fronted.Masquerade{
		Domain:    "midasplayer.com",
		IpAddress: "54.182.0.124",
	},
	&fronted.Masquerade{
		Domain:    "mightybell.com",
		IpAddress: "204.246.164.166",
	},
	&fronted.Masquerade{
		Domain:    "milanuncios.com",
		IpAddress: "54.182.0.134",
	},
	&fronted.Masquerade{
		Domain:    "milkvr.com",
		IpAddress: "204.246.169.40",
	},
	&fronted.Masquerade{
		Domain:    "milkvr.com",
		IpAddress: "54.182.0.66",
	},
	&fronted.Masquerade{
		Domain:    "minecraft.net",
		IpAddress: "54.182.0.133",
	},
	&fronted.Masquerade{
		Domain:    "miracl.com",
		IpAddress: "205.251.253.35",
	},
	&fronted.Masquerade{
		Domain:    "mirriad.com",
		IpAddress: "54.239.130.96",
	},
	&fronted.Masquerade{
		Domain:    "mirriad.com",
		IpAddress: "54.182.0.136",
	},
	&fronted.Masquerade{
		Domain:    "mobi-notification.com",
		IpAddress: "54.182.2.104",
	},
	&fronted.Masquerade{
		Domain:    "mobi2go.com",
		IpAddress: "216.137.33.127",
	},
	&fronted.Masquerade{
		Domain:    "moovitapp.com",
		IpAddress: "205.251.253.254",
	},
	&fronted.Masquerade{
		Domain:    "mparticle.com",
		IpAddress: "54.239.130.123",
	},
	&fronted.Masquerade{
		Domain:    "mparticle.com",
		IpAddress: "204.246.169.214",
	},
	&fronted.Masquerade{
		Domain:    "multisight.com",
		IpAddress: "205.251.253.44",
	},
	&fronted.Masquerade{
		Domain:    "multisight.com",
		IpAddress: "204.246.164.19",
	},
	&fronted.Masquerade{
		Domain:    "multisight.com",
		IpAddress: "54.182.0.189",
	},
	&fronted.Masquerade{
		Domain:    "munchery.com",
		IpAddress: "54.182.0.252",
	},
	&fronted.Masquerade{
		Domain:    "musixmatch.com",
		IpAddress: "54.182.0.135",
	},
	&fronted.Masquerade{
		Domain:    "mybasis.com",
		IpAddress: "204.246.164.193",
	},
	&fronted.Masquerade{
		Domain:    "mybeautyspot.com.au",
		IpAddress: "216.137.33.140",
	},
	&fronted.Masquerade{
		Domain:    "myfitnesspal.com",
		IpAddress: "204.246.164.147",
	},
	&fronted.Masquerade{
		Domain:    "myfonts.net",
		IpAddress: "54.239.130.157",
	},
	&fronted.Masquerade{
		Domain:    "myfonts.net",
		IpAddress: "54.182.1.242",
	},
	&fronted.Masquerade{
		Domain:    "myfonts.net",
		IpAddress: "52.84.2.211",
	},
	&fronted.Masquerade{
		Domain:    "myportfolio.com",
		IpAddress: "54.182.0.155",
	},
	&fronted.Masquerade{
		Domain:    "mytaxi.com",
		IpAddress: "54.239.192.87",
	},
	&fronted.Masquerade{
		Domain:    "mytaxi.com",
		IpAddress: "54.239.130.45",
	},
	&fronted.Masquerade{
		Domain:    "mytaxi.com",
		IpAddress: "54.182.0.64",
	},
	&fronted.Masquerade{
		Domain:    "narendramodi.in",
		IpAddress: "54.182.0.11",
	},
	&fronted.Masquerade{
		Domain:    "navionics.io",
		IpAddress: "204.246.164.126",
	},
	&fronted.Masquerade{
		Domain:    "netcarenow.com",
		IpAddress: "54.182.0.119",
	},
	&fronted.Masquerade{
		Domain:    "netseer.com",
		IpAddress: "54.182.2.13",
	},
	&fronted.Masquerade{
		Domain:    "newsinc.com",
		IpAddress: "216.137.33.175",
	},
	&fronted.Masquerade{
		Domain:    "newsinc.com",
		IpAddress: "54.182.2.220",
	},
	&fronted.Masquerade{
		Domain:    "newsinc.com",
		IpAddress: "205.251.253.223",
	},
	&fronted.Masquerade{
		Domain:    "newsomatic.net",
		IpAddress: "216.137.33.75",
	},
	&fronted.Masquerade{
		Domain:    "nhlstatic.com",
		IpAddress: "54.182.0.49",
	},
	&fronted.Masquerade{
		Domain:    "notonthehighstreet.com",
		IpAddress: "54.182.0.161",
	},
	&fronted.Masquerade{
		Domain:    "novu.com",
		IpAddress: "205.251.253.211",
	},
	&fronted.Masquerade{
		Domain:    "nowforce.com",
		IpAddress: "205.251.253.199",
	},
	&fronted.Masquerade{
		Domain:    "ns-cdn.neustar.biz",
		IpAddress: "54.182.1.165",
	},
	&fronted.Masquerade{
		Domain:    "ns-cdn.neustar.biz",
		IpAddress: "205.251.253.136",
	},
	&fronted.Masquerade{
		Domain:    "nst.sky.it",
		IpAddress: "54.182.2.232",
	},
	&fronted.Masquerade{
		Domain:    "objects.airfrance.com",
		IpAddress: "54.182.1.79",
	},
	&fronted.Masquerade{
		Domain:    "oct.assets.appreciatehub.com",
		IpAddress: "54.239.130.133",
	},
	&fronted.Masquerade{
		Domain:    "onthemarket.com",
		IpAddress: "54.182.1.225",
	},
	&fronted.Masquerade{
		Domain:    "onthemarket.com",
		IpAddress: "204.246.164.201",
	},
	&fronted.Masquerade{
		Domain:    "ooyala.com",
		IpAddress: "54.182.0.97",
	},
	&fronted.Masquerade{
		Domain:    "ooyala.com",
		IpAddress: "54.182.1.197",
	},
	&fronted.Masquerade{
		Domain:    "openoox.com",
		IpAddress: "216.137.33.6",
	},
	&fronted.Masquerade{
		Domain:    "openoox.com",
		IpAddress: "54.182.0.181",
	},
	&fronted.Masquerade{
		Domain:    "orgsync.com",
		IpAddress: "54.182.1.72",
	},
	&fronted.Masquerade{
		Domain:    "origin-preprod.roberthalf.com",
		IpAddress: "54.182.1.212",
	},
	&fronted.Masquerade{
		Domain:    "origin-stage.juniper.net",
		IpAddress: "54.182.1.122",
	},
	&fronted.Masquerade{
		Domain:    "origin-stage.juniper.net",
		IpAddress: "204.246.164.120",
	},
	&fronted.Masquerade{
		Domain:    "oznext.com",
		IpAddress: "205.251.253.95",
	},
	&fronted.Masquerade{
		Domain:    "pactsafe.io",
		IpAddress: "54.182.1.45",
	},
	&fronted.Masquerade{
		Domain:    "pactsafe.io",
		IpAddress: "204.246.164.215",
	},
	&fronted.Masquerade{
		Domain:    "pagamastarde.com",
		IpAddress: "54.182.1.229",
	},
	&fronted.Masquerade{
		Domain:    "pageuppeople.com",
		IpAddress: "54.182.0.90",
	},
	&fronted.Masquerade{
		Domain:    "pageuppeople.com",
		IpAddress: "216.137.33.198",
	},
	&fronted.Masquerade{
		Domain:    "paltalk.com",
		IpAddress: "54.182.1.205",
	},
	&fronted.Masquerade{
		Domain:    "parse.com",
		IpAddress: "54.239.130.31",
	},
	&fronted.Masquerade{
		Domain:    "password.amazonworkspaces.com",
		IpAddress: "54.239.130.176",
	},
	&fronted.Masquerade{
		Domain:    "payments.amazonsha256.com",
		IpAddress: "54.182.1.135",
	},
	&fronted.Masquerade{
		Domain:    "payscale.com",
		IpAddress: "54.182.1.125",
	},
	&fronted.Masquerade{
		Domain:    "peacewithgod.net",
		IpAddress: "54.182.2.209",
	},
	&fronted.Masquerade{
		Domain:    "pearsondev.com",
		IpAddress: "54.239.130.91",
	},
	&fronted.Masquerade{
		Domain:    "pearsondev.com",
		IpAddress: "54.182.1.56",
	},
	&fronted.Masquerade{
		Domain:    "pearsondev.com",
		IpAddress: "205.251.251.188",
	},
	&fronted.Masquerade{
		Domain:    "pearsonrealize.com",
		IpAddress: "54.239.130.115",
	},
	&fronted.Masquerade{
		Domain:    "pearsontexas.com",
		IpAddress: "54.182.0.19",
	},
	&fronted.Masquerade{
		Domain:    "periscope.tv",
		IpAddress: "54.182.0.143",
	},
	&fronted.Masquerade{
		Domain:    "pgastatic.com",
		IpAddress: "216.137.33.39",
	},
	&fronted.Masquerade{
		Domain:    "pgealerts.com",
		IpAddress: "204.246.169.47",
	},
	&fronted.Masquerade{
		Domain:    "pgimgs.com",
		IpAddress: "54.182.0.76",
	},
	&fronted.Masquerade{
		Domain:    "pgimgs.com",
		IpAddress: "205.251.253.244",
	},
	&fronted.Masquerade{
		Domain:    "pgimgs.com",
		IpAddress: "205.251.253.184",
	},
	&fronted.Masquerade{
		Domain:    "pimg.jp",
		IpAddress: "204.246.164.153",
	},
	&fronted.Masquerade{
		Domain:    "pinkoi.com",
		IpAddress: "54.239.130.217",
	},
	&fronted.Masquerade{
		Domain:    "pinterest.com",
		IpAddress: "54.182.1.151",
	},
	&fronted.Masquerade{
		Domain:    "pinterest.com",
		IpAddress: "205.251.253.48",
	},
	&fronted.Masquerade{
		Domain:    "plaid.co.jp",
		IpAddress: "216.137.33.177",
	},
	&fronted.Masquerade{
		Domain:    "play.viralgains.com",
		IpAddress: "54.182.2.121",
	},
	&fronted.Masquerade{
		Domain:    "plaympe.com",
		IpAddress: "205.251.253.29",
	},
	&fronted.Masquerade{
		Domain:    "powermarketing.com",
		IpAddress: "216.137.33.21",
	},
	&fronted.Masquerade{
		Domain:    "preciseres.com",
		IpAddress: "205.251.253.20",
	},
	&fronted.Masquerade{
		Domain:    "preciseres.com",
		IpAddress: "54.239.130.134",
	},
	&fronted.Masquerade{
		Domain:    "predix.io",
		IpAddress: "54.239.130.170",
	},
	&fronted.Masquerade{
		Domain:    "prodstaticcdn.stanfordhealthcare.org",
		IpAddress: "54.182.1.209",
	},
	&fronted.Masquerade{
		Domain:    "productionbeast.com",
		IpAddress: "216.137.33.221",
	},
	&fronted.Masquerade{
		Domain:    "productionbeast.com",
		IpAddress: "54.239.192.231",
	},
	&fronted.Masquerade{
		Domain:    "program-dev.abcradio.net.au",
		IpAddress: "204.246.164.219",
	},
	&fronted.Masquerade{
		Domain:    "program.abcradio.net.au",
		IpAddress: "205.251.253.76",
	},
	&fronted.Masquerade{
		Domain:    "program.abcradio.net.au",
		IpAddress: "54.239.130.225",
	},
	&fronted.Masquerade{
		Domain:    "program.abcradio.net.au",
		IpAddress: "54.182.1.203",
	},
	&fronted.Masquerade{
		Domain:    "promisefinancial.net",
		IpAddress: "54.182.1.223",
	},
	&fronted.Masquerade{
		Domain:    "promotw.com",
		IpAddress: "54.182.0.234",
	},
	&fronted.Masquerade{
		Domain:    "publish.adobe.com",
		IpAddress: "205.251.253.246",
	},
	&fronted.Masquerade{
		Domain:    "pureprofile.com",
		IpAddress: "54.182.1.218",
	},
	&fronted.Masquerade{
		Domain:    "pypestream.com",
		IpAddress: "54.182.1.77",
	},
	&fronted.Masquerade{
		Domain:    "pypestream.com",
		IpAddress: "205.251.253.81",
	},
	&fronted.Masquerade{
		Domain:    "qa.assets.appreciatehub.com",
		IpAddress: "216.137.33.206",
	},
	&fronted.Masquerade{
		Domain:    "qa.media.front.xoedge.com",
		IpAddress: "204.246.164.135",
	},
	&fronted.Masquerade{
		Domain:    "qa.media.front.xoedge.com",
		IpAddress: "216.137.33.161",
	},
	&fronted.Masquerade{
		Domain:    "qa.o.brightcove.com",
		IpAddress: "204.246.164.151",
	},
	&fronted.Masquerade{
		Domain:    "qa2preview.buuteeq.com",
		IpAddress: "54.182.2.63",
	},
	&fronted.Masquerade{
		Domain:    "qkids.com",
		IpAddress: "54.182.1.31",
	},
	&fronted.Masquerade{
		Domain:    "qkids.com",
		IpAddress: "204.246.169.208",
	},
	&fronted.Masquerade{
		Domain:    "quantcast.com",
		IpAddress: "205.251.253.109",
	},
	&fronted.Masquerade{
		Domain:    "quelon.com",
		IpAddress: "216.137.33.239",
	},
	&fronted.Masquerade{
		Domain:    "racing.com",
		IpAddress: "54.239.130.103",
	},
	&fronted.Masquerade{
		Domain:    "racing.com",
		IpAddress: "205.251.253.72",
	},
	&fronted.Masquerade{
		Domain:    "rafflecopter.com",
		IpAddress: "54.182.1.5",
	},
	&fronted.Masquerade{
		Domain:    "rafflecopter.com",
		IpAddress: "54.182.1.226",
	},
	&fronted.Masquerade{
		Domain:    "realeyesit.com",
		IpAddress: "204.246.169.202",
	},
	&fronted.Masquerade{
		Domain:    "realisticgames.co.uk",
		IpAddress: "54.182.1.9",
	},
	&fronted.Masquerade{
		Domain:    "realtime.co",
		IpAddress: "216.137.33.41",
	},
	&fronted.Masquerade{
		Domain:    "realtime.co",
		IpAddress: "205.251.253.172",
	},
	&fronted.Masquerade{
		Domain:    "relateiq.com",
		IpAddress: "54.182.0.240",
	},
	&fronted.Masquerade{
		Domain:    "rentalcar.com",
		IpAddress: "54.182.0.249",
	},
	&fronted.Masquerade{
		Domain:    "renzu.io",
		IpAddress: "54.182.0.33",
	},
	&fronted.Masquerade{
		Domain:    "repo.mongodb.org",
		IpAddress: "54.239.130.9",
	},
	&fronted.Masquerade{
		Domain:    "resources.amazonwebapps.com",
		IpAddress: "54.239.130.188",
	},
	&fronted.Masquerade{
		Domain:    "resources.amazonwebapps.com",
		IpAddress: "216.137.33.223",
	},
	&fronted.Masquerade{
		Domain:    "resources.amazonwebapps.com",
		IpAddress: "205.251.253.240",
	},
	&fronted.Masquerade{
		Domain:    "rewardstyle.com",
		IpAddress: "54.182.0.107",
	},
	&fronted.Masquerade{
		Domain:    "rhythmone.com",
		IpAddress: "204.246.164.84",
	},
	&fronted.Masquerade{
		Domain:    "riffsy.com",
		IpAddress: "54.182.1.82",
	},
	&fronted.Masquerade{
		Domain:    "rl.talis.com",
		IpAddress: "205.251.253.30",
	},
	&fronted.Masquerade{
		Domain:    "rlcdn.com",
		IpAddress: "54.239.130.223",
	},
	&fronted.Masquerade{
		Domain:    "rockabox.co",
		IpAddress: "54.182.1.123",
	},
	&fronted.Masquerade{
		Domain:    "rockabox.co",
		IpAddress: "205.251.253.166",
	},
	&fronted.Masquerade{
		Domain:    "roomorama.com",
		IpAddress: "205.251.253.123",
	},
	&fronted.Masquerade{
		Domain:    "rosettastone.com",
		IpAddress: "54.182.2.35",
	},
	&fronted.Masquerade{
		Domain:    "rounds.com",
		IpAddress: "54.239.130.37",
	},
	&fronted.Masquerade{
		Domain:    "rr2-us-vir-1-content.flarecloud.net",
		IpAddress: "204.246.164.204",
	},
	&fronted.Masquerade{
		Domain:    "rr2-us-vir-1-content.flarecloud.net",
		IpAddress: "205.251.253.157",
	},
	&fronted.Masquerade{
		Domain:    "rr2-us-vir-1-content.flarecloud.net",
		IpAddress: "54.182.0.245",
	},
	&fronted.Masquerade{
		Domain:    "rsrve.com",
		IpAddress: "54.182.0.20",
	},
	&fronted.Masquerade{
		Domain:    "rsrve.com",
		IpAddress: "205.251.251.91",
	},
	&fronted.Masquerade{
		Domain:    "rsvp.com.au",
		IpAddress: "54.182.1.40",
	},
	&fronted.Masquerade{
		Domain:    "rsvp.com.au",
		IpAddress: "205.251.253.154",
	},
	&fronted.Masquerade{
		Domain:    "rtl.nl",
		IpAddress: "54.182.0.13",
	},
	&fronted.Masquerade{
		Domain:    "rtl.nl",
		IpAddress: "205.251.253.91",
	},
	&fronted.Masquerade{
		Domain:    "rtl.nl",
		IpAddress: "54.182.0.243",
	},
	&fronted.Masquerade{
		Domain:    "rwaws.com",
		IpAddress: "54.182.2.218",
	},
	&fronted.Masquerade{
		Domain:    "rwaws.com",
		IpAddress: "54.182.2.17",
	},
	&fronted.Masquerade{
		Domain:    "s.kuruvia.com",
		IpAddress: "54.182.1.23",
	},
	&fronted.Masquerade{
		Domain:    "s.squixa.net",
		IpAddress: "54.239.130.135",
	},
	&fronted.Masquerade{
		Domain:    "s.squixa.net",
		IpAddress: "54.182.0.59",
	},
	&fronted.Masquerade{
		Domain:    "s.squixa.net",
		IpAddress: "204.246.164.190",
	},
	&fronted.Masquerade{
		Domain:    "s3-accelerate.amazonaws.com",
		IpAddress: "54.192.0.24",
	},
	&fronted.Masquerade{
		Domain:    "s3-turbo.amazonaws.com",
		IpAddress: "204.246.164.142",
	},
	&fronted.Masquerade{
		Domain:    "s3-turbo.amazonaws.com",
		IpAddress: "205.251.253.125",
	},
	&fronted.Masquerade{
		Domain:    "salesforcesos.com",
		IpAddress: "54.182.1.154",
	},
	&fronted.Masquerade{
		Domain:    "samsungcloudsolution.com",
		IpAddress: "54.182.0.54",
	},
	&fronted.Masquerade{
		Domain:    "samsungknowledge.com",
		IpAddress: "54.182.2.182",
	},
	&fronted.Masquerade{
		Domain:    "samsungknowledge.com",
		IpAddress: "54.239.130.215",
	},
	&fronted.Masquerade{
		Domain:    "sanoma.com",
		IpAddress: "54.182.1.239",
	},
	&fronted.Masquerade{
		Domain:    "saucelabs.com",
		IpAddress: "204.246.164.162",
	},
	&fronted.Masquerade{
		Domain:    "schibsted.com",
		IpAddress: "204.246.164.171",
	},
	&fronted.Masquerade{
		Domain:    "schibsted.com",
		IpAddress: "54.182.1.238",
	},
	&fronted.Masquerade{
		Domain:    "schibsted.com",
		IpAddress: "54.239.130.73",
	},
	&fronted.Masquerade{
		Domain:    "schibsted.com",
		IpAddress: "216.137.33.129",
	},
	&fronted.Masquerade{
		Domain:    "scoopon.com.au",
		IpAddress: "216.137.33.84",
	},
	&fronted.Masquerade{
		Domain:    "scribblelive.com",
		IpAddress: "54.182.0.115",
	},
	&fronted.Masquerade{
		Domain:    "scruff.com",
		IpAddress: "54.182.1.164",
	},
	&fronted.Masquerade{
		Domain:    "scruffapp.com",
		IpAddress: "54.239.130.114",
	},
	&fronted.Masquerade{
		Domain:    "scup.com",
		IpAddress: "204.246.164.127",
	},
	&fronted.Masquerade{
		Domain:    "seattletimes.com",
		IpAddress: "216.137.33.217",
	},
	&fronted.Masquerade{
		Domain:    "seattletimes.com",
		IpAddress: "54.182.0.27",
	},
	&fronted.Masquerade{
		Domain:    "secondlife-staging.com",
		IpAddress: "54.182.1.29",
	},
	&fronted.Masquerade{
		Domain:    "secure.paystack.com",
		IpAddress: "216.137.33.189",
	},
	&fronted.Masquerade{
		Domain:    "selflender.net",
		IpAddress: "205.251.253.146",
	},
	&fronted.Masquerade{
		Domain:    "selflender.net",
		IpAddress: "54.182.0.39",
	},
	&fronted.Masquerade{
		Domain:    "seriemundial.com",
		IpAddress: "216.137.33.38",
	},
	&fronted.Masquerade{
		Domain:    "seriemundial.com",
		IpAddress: "54.182.2.98",
	},
	&fronted.Masquerade{
		Domain:    "servicechannel.com",
		IpAddress: "204.246.164.77",
	},
	&fronted.Masquerade{
		Domain:    "services.adobe.com",
		IpAddress: "54.182.1.20",
	},
	&fronted.Masquerade{
		Domain:    "services.adobe.com",
		IpAddress: "205.251.253.41",
	},
	&fronted.Masquerade{
		Domain:    "sharecare.com",
		IpAddress: "204.246.164.108",
	},
	&fronted.Masquerade{
		Domain:    "sharefile.com",
		IpAddress: "54.239.130.186",
	},
	&fronted.Masquerade{
		Domain:    "sharefile.com",
		IpAddress: "54.182.0.83",
	},
	&fronted.Masquerade{
		Domain:    "sharethis.com",
		IpAddress: "54.239.130.38",
	},
	&fronted.Masquerade{
		Domain:    "shopstyle.com",
		IpAddress: "216.137.33.141",
	},
	&fronted.Masquerade{
		Domain:    "shopstyle.com",
		IpAddress: "54.239.130.75",
	},
	&fronted.Masquerade{
		Domain:    "shopstyle.com",
		IpAddress: "205.251.253.171",
	},
	&fronted.Masquerade{
		Domain:    "signal.is",
		IpAddress: "205.251.253.71",
	},
	&fronted.Masquerade{
		Domain:    "sjc.io",
		IpAddress: "54.182.1.152",
	},
	&fronted.Masquerade{
		Domain:    "sketchup.com",
		IpAddress: "54.182.1.249",
	},
	&fronted.Masquerade{
		Domain:    "sketchup.com",
		IpAddress: "54.182.1.179",
	},
	&fronted.Masquerade{
		Domain:    "sketchup.com",
		IpAddress: "205.251.253.122",
	},
	&fronted.Masquerade{
		Domain:    "slack-files.com",
		IpAddress: "54.182.0.112",
	},
	&fronted.Masquerade{
		Domain:    "slack.com",
		IpAddress: "216.137.33.149",
	},
	&fronted.Masquerade{
		Domain:    "sling.com",
		IpAddress: "54.182.1.222",
	},
	&fronted.Masquerade{
		Domain:    "smaatolabs.net",
		IpAddress: "54.239.130.77",
	},
	&fronted.Masquerade{
		Domain:    "smartica.jp",
		IpAddress: "216.137.33.214",
	},
	&fronted.Masquerade{
		Domain:    "smartrecruiters.com",
		IpAddress: "54.182.1.91",
	},
	&fronted.Masquerade{
		Domain:    "smartrecruiters.com",
		IpAddress: "54.239.130.100",
	},
	&fronted.Masquerade{
		Domain:    "smyte.com",
		IpAddress: "54.182.1.193",
	},
	&fronted.Masquerade{
		Domain:    "snapapp.com",
		IpAddress: "54.182.1.170",
	},
	&fronted.Masquerade{
		Domain:    "snapapp.com",
		IpAddress: "54.239.130.87",
	},
	&fronted.Masquerade{
		Domain:    "snapapp.com",
		IpAddress: "205.251.253.38",
	},
	&fronted.Masquerade{
		Domain:    "sny.tv",
		IpAddress: "54.182.0.38",
	},
	&fronted.Masquerade{
		Domain:    "snystatic.tv",
		IpAddress: "54.182.0.200",
	},
	&fronted.Masquerade{
		Domain:    "society6.com",
		IpAddress: "54.239.130.231",
	},
	&fronted.Masquerade{
		Domain:    "sonicwall.com",
		IpAddress: "54.182.0.92",
	},
	&fronted.Masquerade{
		Domain:    "sorensonmedia.com",
		IpAddress: "54.182.0.131",
	},
	&fronted.Masquerade{
		Domain:    "spark.autodesk.com",
		IpAddress: "54.182.0.193",
	},
	&fronted.Masquerade{
		Domain:    "sparxcdn.net",
		IpAddress: "54.239.130.78",
	},
	&fronted.Masquerade{
		Domain:    "sparxcdn.net",
		IpAddress: "205.251.253.227",
	},
	&fronted.Masquerade{
		Domain:    "spd.samsungdm.com",
		IpAddress: "54.182.1.142",
	},
	&fronted.Masquerade{
		Domain:    "spd.samsungdm.com",
		IpAddress: "204.246.169.207",
	},
	&fronted.Masquerade{
		Domain:    "sporaga.com",
		IpAddress: "205.251.253.176",
	},
	&fronted.Masquerade{
		Domain:    "sportsyapper.com",
		IpAddress: "54.239.130.107",
	},
	&fronted.Masquerade{
		Domain:    "stage.mozaws.net",
		IpAddress: "205.251.253.84",
	},
	&fronted.Masquerade{
		Domain:    "staging.download.inky.com",
		IpAddress: "54.182.0.206",
	},
	&fronted.Masquerade{
		Domain:    "static-assets.shoptv.com",
		IpAddress: "54.239.130.88",
	},
	&fronted.Masquerade{
		Domain:    "static-assets.shoptv.com",
		IpAddress: "54.182.1.253",
	},
	&fronted.Masquerade{
		Domain:    "static.emarsys.com",
		IpAddress: "204.246.164.96",
	},
	&fronted.Masquerade{
		Domain:    "static.emarsys.com",
		IpAddress: "54.239.130.13",
	},
	&fronted.Masquerade{
		Domain:    "static.id.fc2cn.com",
		IpAddress: "204.246.164.73",
	},
	&fronted.Masquerade{
		Domain:    "static.id.fc2cn.com",
		IpAddress: "54.182.2.81",
	},
	&fronted.Masquerade{
		Domain:    "static.suite.io",
		IpAddress: "54.239.130.49",
	},
	&fronted.Masquerade{
		Domain:    "static.yub-cdn.com",
		IpAddress: "54.182.1.200",
	},
	&fronted.Masquerade{
		Domain:    "static.yub-cdn.com",
		IpAddress: "205.251.253.103",
	},
	&fronted.Masquerade{
		Domain:    "statista.com",
		IpAddress: "54.182.1.35",
	},
	&fronted.Masquerade{
		Domain:    "stg.assets.appreciatehub.com",
		IpAddress: "54.182.0.147",
	},
	&fronted.Masquerade{
		Domain:    "stg.ziprecruiter.com",
		IpAddress: "54.182.1.4",
	},
	&fronted.Masquerade{
		Domain:    "stg.ziprecruiter.com",
		IpAddress: "54.239.130.118",
	},
	&fronted.Masquerade{
		Domain:    "strongholdfinancial.com",
		IpAddress: "54.239.130.10",
	},
	&fronted.Masquerade{
		Domain:    "strongholdfinancial.com",
		IpAddress: "54.182.0.23",
	},
	&fronted.Masquerade{
		Domain:    "subscribe.nhl.com",
		IpAddress: "205.251.253.142",
	},
	&fronted.Masquerade{
		Domain:    "sundaysky.com",
		IpAddress: "205.251.253.174",
	},
	&fronted.Masquerade{
		Domain:    "sup-gcsp.jnj.com",
		IpAddress: "54.239.130.171",
	},
	&fronted.Masquerade{
		Domain:    "sup-gcsp.jnj.com",
		IpAddress: "54.182.2.143",
	},
	&fronted.Masquerade{
		Domain:    "superrewards-offers.com",
		IpAddress: "54.182.2.163",
	},
	&fronted.Masquerade{
		Domain:    "superrewards-offers.com",
		IpAddress: "54.182.2.229",
	},
	&fronted.Masquerade{
		Domain:    "superrewards-offers.com",
		IpAddress: "204.246.164.63",
	},
	&fronted.Masquerade{
		Domain:    "synapse-link.com",
		IpAddress: "205.251.253.247",
	},
	&fronted.Masquerade{
		Domain:    "synapse-link.com",
		IpAddress: "54.182.0.244",
	},
	&fronted.Masquerade{
		Domain:    "tab.com.au",
		IpAddress: "205.251.253.226",
	},
	&fronted.Masquerade{
		Domain:    "tagboard.com",
		IpAddress: "54.182.1.234",
	},
	&fronted.Masquerade{
		Domain:    "tango.me",
		IpAddress: "54.239.130.220",
	},
	&fronted.Masquerade{
		Domain:    "tapad.com",
		IpAddress: "54.182.0.26",
	},
	&fronted.Masquerade{
		Domain:    "tapjoy.com",
		IpAddress: "54.182.0.139",
	},
	&fronted.Masquerade{
		Domain:    "tapjoyads.com",
		IpAddress: "205.251.253.94",
	},
	&fronted.Masquerade{
		Domain:    "taskcluster.net",
		IpAddress: "54.182.2.201",
	},
	&fronted.Masquerade{
		Domain:    "techrocket.com",
		IpAddress: "54.182.2.144",
	},
	&fronted.Masquerade{
		Domain:    "telestream.net",
		IpAddress: "54.239.130.76",
	},
	&fronted.Masquerade{
		Domain:    "testnav.com",
		IpAddress: "204.246.164.133",
	},
	&fronted.Masquerade{
		Domain:    "testnav.com",
		IpAddress: "54.239.130.148",
	},
	&fronted.Masquerade{
		Domain:    "testshop.shopch.jp",
		IpAddress: "54.182.2.49",
	},
	&fronted.Masquerade{
		Domain:    "textio.com",
		IpAddress: "54.182.1.192",
	},
	&fronted.Masquerade{
		Domain:    "textio.com",
		IpAddress: "216.137.33.42",
	},
	&fronted.Masquerade{
		Domain:    "textio.com",
		IpAddress: "204.246.164.27",
	},
	&fronted.Masquerade{
		Domain:    "theitnation.com",
		IpAddress: "204.246.164.156",
	},
	&fronted.Masquerade{
		Domain:    "theitnation.com",
		IpAddress: "54.239.130.130",
	},
	&fronted.Masquerade{
		Domain:    "theknot.com",
		IpAddress: "54.182.0.175",
	},
	&fronted.Masquerade{
		Domain:    "theknot.com",
		IpAddress: "204.246.164.82",
	},
	&fronted.Masquerade{
		Domain:    "theknot.com",
		IpAddress: "54.182.1.214",
	},
	&fronted.Masquerade{
		Domain:    "thinknearhub.com",
		IpAddress: "205.251.253.62",
	},
	&fronted.Masquerade{
		Domain:    "thrillcall.com",
		IpAddress: "216.137.33.139",
	},
	&fronted.Masquerade{
		Domain:    "tickr.com",
		IpAddress: "216.137.33.63",
	},
	&fronted.Masquerade{
		Domain:    "tickr.com",
		IpAddress: "54.239.130.181",
	},
	&fronted.Masquerade{
		Domain:    "tickr.com",
		IpAddress: "54.182.2.195",
	},
	&fronted.Masquerade{
		Domain:    "tigerwoodsfoundation.org",
		IpAddress: "54.182.1.186",
	},
	&fronted.Masquerade{
		Domain:    "timeincukcontent.com",
		IpAddress: "54.239.130.193",
	},
	&fronted.Masquerade{
		Domain:    "timeincukcontent.com",
		IpAddress: "204.246.169.6",
	},
	&fronted.Masquerade{
		Domain:    "tinkercad.com",
		IpAddress: "54.182.1.145",
	},
	&fronted.Masquerade{
		Domain:    "tlo.com",
		IpAddress: "205.251.253.27",
	},
	&fronted.Masquerade{
		Domain:    "tlo.com",
		IpAddress: "54.182.2.99",
	},
	&fronted.Masquerade{
		Domain:    "toons.tv",
		IpAddress: "54.182.2.130",
	},
	&fronted.Masquerade{
		Domain:    "topspin.net",
		IpAddress: "54.239.130.228",
	},
	&fronted.Masquerade{
		Domain:    "tp-staging.com",
		IpAddress: "54.182.1.80",
	},
	&fronted.Masquerade{
		Domain:    "trafalgar.com",
		IpAddress: "54.182.0.180",
	},
	&fronted.Masquerade{
		Domain:    "traversedlp.com",
		IpAddress: "54.182.1.230",
	},
	&fronted.Masquerade{
		Domain:    "tresensa.com",
		IpAddress: "205.251.253.245",
	},
	&fronted.Masquerade{
		Domain:    "trover.com",
		IpAddress: "54.182.0.81",
	},
	&fronted.Masquerade{
		Domain:    "trover.com",
		IpAddress: "204.246.169.248",
	},
	&fronted.Masquerade{
		Domain:    "trunkclub.com",
		IpAddress: "54.182.0.230",
	},
	&fronted.Masquerade{
		Domain:    "trusteerqa.com",
		IpAddress: "54.182.1.252",
	},
	&fronted.Masquerade{
		Domain:    "trustpilot.com",
		IpAddress: "54.182.2.21",
	},
	&fronted.Masquerade{
		Domain:    "tstatic.eu",
		IpAddress: "54.182.2.56",
	},
	&fronted.Masquerade{
		Domain:    "tto.intuitcdn.net",
		IpAddress: "205.251.253.78",
	},
	&fronted.Masquerade{
		Domain:    "tto.intuitcdn.net",
		IpAddress: "54.239.130.202",
	},
	&fronted.Masquerade{
		Domain:    "tto.preprod.intuitcdn.net",
		IpAddress: "54.182.0.160",
	},
	&fronted.Masquerade{
		Domain:    "twinehealth.com",
		IpAddress: "216.137.33.130",
	},
	&fronted.Masquerade{
		Domain:    "twitch.tv",
		IpAddress: "216.137.33.73",
	},
	&fronted.Masquerade{
		Domain:    "typekit.net",
		IpAddress: "54.239.130.179",
	},
	&fronted.Masquerade{
		Domain:    "typekit.net",
		IpAddress: "54.182.2.159",
	},
	&fronted.Masquerade{
		Domain:    "typekit.net",
		IpAddress: "54.239.130.50",
	},
	&fronted.Masquerade{
		Domain:    "ubnt.com",
		IpAddress: "216.137.33.143",
	},
	&fronted.Masquerade{
		Domain:    "ubnt.com",
		IpAddress: "54.239.130.22",
	},
	&fronted.Masquerade{
		Domain:    "ulpurview.com",
		IpAddress: "54.182.0.114",
	},
	&fronted.Masquerade{
		Domain:    "ulpurview.com",
		IpAddress: "216.137.33.30",
	},
	&fronted.Masquerade{
		Domain:    "ulpurview.com",
		IpAddress: "204.246.164.49",
	},
	&fronted.Masquerade{
		Domain:    "ulpurview.com",
		IpAddress: "54.239.130.56",
	},
	&fronted.Masquerade{
		Domain:    "ulpurview.com",
		IpAddress: "205.251.253.21",
	},
	&fronted.Masquerade{
		Domain:    "ulpurview.com",
		IpAddress: "216.137.33.247",
	},
	&fronted.Masquerade{
		Domain:    "undercovertourist.com",
		IpAddress: "54.182.1.124",
	},
	&fronted.Masquerade{
		Domain:    "unleashus.org",
		IpAddress: "54.182.2.228",
	},
	&fronted.Masquerade{
		Domain:    "unpacked-test.com",
		IpAddress: "216.137.33.133",
	},
	&fronted.Masquerade{
		Domain:    "unrealengine.com",
		IpAddress: "54.239.130.198",
	},
	&fronted.Masquerade{
		Domain:    "updates.onapsis.com",
		IpAddress: "54.182.1.92",
	},
	&fronted.Masquerade{
		Domain:    "updates.onapsis.com",
		IpAddress: "205.251.253.57",
	},
	&fronted.Masquerade{
		Domain:    "uprinting.com",
		IpAddress: "205.251.253.68",
	},
	&fronted.Masquerade{
		Domain:    "us.whispir.com",
		IpAddress: "54.239.130.184",
	},
	&fronted.Masquerade{
		Domain:    "useiti.doi.gov",
		IpAddress: "54.182.0.109",
	},
	&fronted.Masquerade{
		Domain:    "userdive.com",
		IpAddress: "54.182.0.237",
	},
	&fronted.Masquerade{
		Domain:    "ustyme.com",
		IpAddress: "54.182.2.26",
	},
	&fronted.Masquerade{
		Domain:    "vdna-assets.com",
		IpAddress: "54.182.0.52",
	},
	&fronted.Masquerade{
		Domain:    "veeam.com",
		IpAddress: "204.246.164.24",
	},
	&fronted.Masquerade{
		Domain:    "veeam.com",
		IpAddress: "54.182.0.192",
	},
	&fronted.Masquerade{
		Domain:    "veeemotion.com",
		IpAddress: "204.246.164.18",
	},
	&fronted.Masquerade{
		Domain:    "verbling.com",
		IpAddress: "204.246.164.172",
	},
	&fronted.Masquerade{
		Domain:    "video.theblaze.com",
		IpAddress: "216.137.33.232",
	},
	&fronted.Masquerade{
		Domain:    "videologygroup.com",
		IpAddress: "54.239.130.11",
	},
	&fronted.Masquerade{
		Domain:    "videologygroup.com",
		IpAddress: "54.182.0.93",
	},
	&fronted.Masquerade{
		Domain:    "videopolis.com",
		IpAddress: "54.182.1.39",
	},
	&fronted.Masquerade{
		Domain:    "videopolis.com",
		IpAddress: "204.246.164.213",
	},
	&fronted.Masquerade{
		Domain:    "vivareal.com",
		IpAddress: "54.182.0.158",
	},
	&fronted.Masquerade{
		Domain:    "vivino.com",
		IpAddress: "205.251.253.140",
	},
	&fronted.Masquerade{
		Domain:    "vivino.com",
		IpAddress: "54.182.0.88",
	},
	&fronted.Masquerade{
		Domain:    "vivoom.co",
		IpAddress: "54.239.130.174",
	},
	&fronted.Masquerade{
		Domain:    "vle.unicafuniversity.com",
		IpAddress: "205.251.253.36",
	},
	&fronted.Masquerade{
		Domain:    "vle.unicafuniversity.com",
		IpAddress: "54.239.130.66",
	},
	&fronted.Masquerade{
		Domain:    "voluum.com",
		IpAddress: "54.182.0.69",
	},
	&fronted.Masquerade{
		Domain:    "walkme.com",
		IpAddress: "54.239.194.181",
	},
	&fronted.Masquerade{
		Domain:    "walkmeqa.com",
		IpAddress: "54.182.0.220",
	},
	&fronted.Masquerade{
		Domain:    "warehouse.meteor.com",
		IpAddress: "54.182.0.164",
	},
	&fronted.Masquerade{
		Domain:    "warehouse.tekla.com",
		IpAddress: "54.239.130.150",
	},
	&fronted.Masquerade{
		Domain:    "warehouse.tekla.com",
		IpAddress: "205.251.251.214",
	},
	&fronted.Masquerade{
		Domain:    "warehouse.tekla.com",
		IpAddress: "54.182.0.241",
	},
	&fronted.Masquerade{
		Domain:    "wayinhub.com",
		IpAddress: "216.137.33.96",
	},
	&fronted.Masquerade{
		Domain:    "wayinhub.com",
		IpAddress: "205.251.253.31",
	},
	&fronted.Masquerade{
		Domain:    "web.nhl.com",
		IpAddress: "205.251.253.237",
	},
	&fronted.Masquerade{
		Domain:    "webspectator.com",
		IpAddress: "54.239.130.35",
	},
	&fronted.Masquerade{
		Domain:    "weddingwire.com",
		IpAddress: "54.239.130.138",
	},
	&fronted.Masquerade{
		Domain:    "weddingwire.com",
		IpAddress: "54.239.130.71",
	},
	&fronted.Masquerade{
		Domain:    "weddingwire.com",
		IpAddress: "54.182.1.7",
	},
	&fronted.Masquerade{
		Domain:    "weddingwire.com",
		IpAddress: "216.137.33.156",
	},
	&fronted.Masquerade{
		Domain:    "weebo.it",
		IpAddress: "54.182.1.232",
	},
	&fronted.Masquerade{
		Domain:    "weebo.it",
		IpAddress: "204.246.164.66",
	},
	&fronted.Masquerade{
		Domain:    "weebo.it",
		IpAddress: "54.182.0.167",
	},
	&fronted.Masquerade{
		Domain:    "werally.com",
		IpAddress: "205.251.253.170",
	},
	&fronted.Masquerade{
		Domain:    "whispir.com",
		IpAddress: "54.182.0.85",
	},
	&fronted.Masquerade{
		Domain:    "whizz.com",
		IpAddress: "54.239.130.28",
	},
	&fronted.Masquerade{
		Domain:    "wholelattelove.com",
		IpAddress: "54.182.1.114",
	},
	&fronted.Masquerade{
		Domain:    "whoscall.com",
		IpAddress: "54.182.0.99",
	},
	&fronted.Masquerade{
		Domain:    "wms-na.amazon-adsystem.com",
		IpAddress: "205.251.253.215",
	},
	&fronted.Masquerade{
		Domain:    "wp.rgnrtr.com",
		IpAddress: "205.251.253.219",
	},
	&fronted.Masquerade{
		Domain:    "wpcp.shiseido.co.jp",
		IpAddress: "204.246.164.102",
	},
	&fronted.Masquerade{
		Domain:    "ws.sonos.com",
		IpAddress: "54.182.0.127",
	},
	&fronted.Masquerade{
		Domain:    "www.amanaartphoto.com",
		IpAddress: "54.182.1.21",
	},
	&fronted.Masquerade{
		Domain:    "www.amanaartphoto.com",
		IpAddress: "54.182.1.78",
	},
	&fronted.Masquerade{
		Domain:    "www.amazonsha256.com",
		IpAddress: "54.239.130.70",
	},
	&fronted.Masquerade{
		Domain:    "www.anthq.com",
		IpAddress: "54.239.130.59",
	},
	&fronted.Masquerade{
		Domain:    "www.api.brightcove.com",
		IpAddress: "205.251.253.25",
	},
	&fronted.Masquerade{
		Domain:    "www.api.brightcove.com",
		IpAddress: "54.182.1.176",
	},
	&fronted.Masquerade{
		Domain:    "www.api.brightcove.com",
		IpAddress: "54.239.130.144",
	},
	&fronted.Masquerade{
		Domain:    "www.apps.umbel.com",
		IpAddress: "54.182.1.195",
	},
	&fronted.Masquerade{
		Domain:    "www.asahi-kasei.co.jp",
		IpAddress: "54.182.1.117",
	},
	&fronted.Masquerade{
		Domain:    "www.autodata-group.com",
		IpAddress: "54.182.1.26",
	},
	&fronted.Masquerade{
		Domain:    "www.autodata-group.com",
		IpAddress: "216.137.33.219",
	},
	&fronted.Masquerade{
		Domain:    "www.autodata-group.com",
		IpAddress: "205.251.253.178",
	},
	&fronted.Masquerade{
		Domain:    "www.awsevents.com",
		IpAddress: "54.239.194.227",
	},
	&fronted.Masquerade{
		Domain:    "www.awsevents.com",
		IpAddress: "54.239.194.117",
	},
	&fronted.Masquerade{
		Domain:    "www.awsevents.com",
		IpAddress: "216.137.33.18",
	},
	&fronted.Masquerade{
		Domain:    "www.awsstatic.com",
		IpAddress: "205.251.253.202",
	},
	&fronted.Masquerade{
		Domain:    "www.awsstatic.com",
		IpAddress: "205.251.253.66",
	},
	&fronted.Masquerade{
		Domain:    "www.awsstatic.com",
		IpAddress: "54.239.130.122",
	},
	&fronted.Masquerade{
		Domain:    "www.b2b.tp-staging.com",
		IpAddress: "54.182.1.74",
	},
	&fronted.Masquerade{
		Domain:    "www.b2b.tp-testing.com",
		IpAddress: "54.239.130.112",
	},
	&fronted.Masquerade{
		Domain:    "www.b2b.tp-testing.com",
		IpAddress: "54.182.0.188",
	},
	&fronted.Masquerade{
		Domain:    "www.b2b.tp-testing.com",
		IpAddress: "204.246.169.24",
	},
	&fronted.Masquerade{
		Domain:    "www.b2b.trustpilot.com",
		IpAddress: "54.239.130.200",
	},
	&fronted.Masquerade{
		Domain:    "www.ccpsx.com",
		IpAddress: "54.182.2.7",
	},
	&fronted.Masquerade{
		Domain:    "www.cdn.telerik.com",
		IpAddress: "54.239.130.212",
	},
	&fronted.Masquerade{
		Domain:    "www.clients.litmuscdn.com",
		IpAddress: "54.182.0.46",
	},
	&fronted.Masquerade{
		Domain:    "www.connectwise.co.uk",
		IpAddress: "54.182.0.191",
	},
	&fronted.Masquerade{
		Domain:    "www.currencyfair.com",
		IpAddress: "216.137.33.151",
	},
	&fronted.Masquerade{
		Domain:    "www.currencyfair.com",
		IpAddress: "54.182.2.191",
	},
	&fronted.Masquerade{
		Domain:    "www.cvc.com.br",
		IpAddress: "216.137.33.162",
	},
	&fronted.Masquerade{
		Domain:    "www.cvc.com.br",
		IpAddress: "54.182.1.111",
	},
	&fronted.Masquerade{
		Domain:    "www.cvc.com.br",
		IpAddress: "204.246.164.243",
	},
	&fronted.Masquerade{
		Domain:    "www.d.dmds.amzdgmsc.com",
		IpAddress: "54.182.2.139",
	},
	&fronted.Masquerade{
		Domain:    "www.d.dmds.amzdgmsc.com",
		IpAddress: "204.246.164.125",
	},
	&fronted.Masquerade{
		Domain:    "www.diageo.com",
		IpAddress: "205.251.253.248",
	},
	&fronted.Masquerade{
		Domain:    "www.diageo.com",
		IpAddress: "216.137.33.54",
	},
	&fronted.Masquerade{
		Domain:    "www.diageo.com",
		IpAddress: "54.239.192.27",
	},
	&fronted.Masquerade{
		Domain:    "www.diageo.com",
		IpAddress: "205.251.253.6",
	},
	&fronted.Masquerade{
		Domain:    "www.diageo.com",
		IpAddress: "204.246.164.221",
	},
	&fronted.Masquerade{
		Domain:    "www.diageohorizon.com",
		IpAddress: "54.182.0.32",
	},
	&fronted.Masquerade{
		Domain:    "www.diageohorizon.com",
		IpAddress: "54.182.0.50",
	},
	&fronted.Masquerade{
		Domain:    "www.diageohorizon.com",
		IpAddress: "54.182.0.140",
	},
	&fronted.Masquerade{
		Domain:    "www.diageohorizon.com",
		IpAddress: "54.182.1.61",
	},
	&fronted.Masquerade{
		Domain:    "www.diageohorizon.com",
		IpAddress: "54.239.130.124",
	},
	&fronted.Masquerade{
		Domain:    "www.diageohorizon.com",
		IpAddress: "54.239.130.85",
	},
	&fronted.Masquerade{
		Domain:    "www.execute-api.ap-northeast-1.amazonaws.com",
		IpAddress: "205.251.253.230",
	},
	&fronted.Masquerade{
		Domain:    "www.execute-api.eu-west-1.amazonaws.com",
		IpAddress: "54.182.1.137",
	},
	&fronted.Masquerade{
		Domain:    "www.execute-api.us-west-2.amazonaws.com",
		IpAddress: "54.239.130.58",
	},
	&fronted.Masquerade{
		Domain:    "www.execute-api.us-west-2.amazonaws.com",
		IpAddress: "54.182.1.171",
	},
	&fronted.Masquerade{
		Domain:    "www.fanduel.com",
		IpAddress: "54.182.1.172",
	},
	&fronted.Masquerade{
		Domain:    "www.fanduel.com",
		IpAddress: "54.239.130.6",
	},
	&fronted.Masquerade{
		Domain:    "www.flashgamesrockstar00.flashgamesrockstar.com",
		IpAddress: "205.251.253.28",
	},
	&fronted.Masquerade{
		Domain:    "www.flashgamesrockstar00.flashgamesrockstar.com",
		IpAddress: "54.182.0.21",
	},
	&fronted.Masquerade{
		Domain:    "www.fogcity.digital",
		IpAddress: "54.239.130.143",
	},
	&fronted.Masquerade{
		Domain:    "www.games.dev.starmp.com",
		IpAddress: "54.182.0.207",
	},
	&fronted.Masquerade{
		Domain:    "www.gaydar.net",
		IpAddress: "54.239.130.219",
	},
	&fronted.Masquerade{
		Domain:    "www.gaydar.net",
		IpAddress: "205.251.253.24",
	},
	&fronted.Masquerade{
		Domain:    "www.gigmasters.com",
		IpAddress: "216.137.33.14",
	},
	&fronted.Masquerade{
		Domain:    "www.glico.com",
		IpAddress: "54.182.0.44",
	},
	&fronted.Masquerade{
		Domain:    "www.glico.com",
		IpAddress: "216.137.33.226",
	},
	&fronted.Masquerade{
		Domain:    "www.keystone-jobs.com",
		IpAddress: "54.182.1.14",
	},
	&fronted.Masquerade{
		Domain:    "www.ksmobile.com",
		IpAddress: "54.239.194.49",
	},
	&fronted.Masquerade{
		Domain:    "www.ksmobile.com",
		IpAddress: "54.182.1.245",
	},
	&fronted.Masquerade{
		Domain:    "www.ksmobile.com",
		IpAddress: "204.246.164.11",
	},
	&fronted.Masquerade{
		Domain:    "www.ksmobile.com",
		IpAddress: "204.246.164.32",
	},
	&fronted.Masquerade{
		Domain:    "www.ksmobile.com",
		IpAddress: "204.246.164.47",
	},
	&fronted.Masquerade{
		Domain:    "www.memb.ft.com",
		IpAddress: "204.246.164.169",
	},
	&fronted.Masquerade{
		Domain:    "www.memb.ft.com",
		IpAddress: "204.246.164.187",
	},
	&fronted.Masquerade{
		Domain:    "www.metacdn.com",
		IpAddress: "205.251.253.22",
	},
	&fronted.Masquerade{
		Domain:    "www.oneclickventures.com",
		IpAddress: "54.182.1.54",
	},
	&fronted.Masquerade{
		Domain:    "www.origin.tumblr.com",
		IpAddress: "54.239.130.209",
	},
	&fronted.Masquerade{
		Domain:    "www.outlandercommunity.com",
		IpAddress: "204.246.164.244",
	},
	&fronted.Masquerade{
		Domain:    "www.outlandercommunity.com",
		IpAddress: "205.251.253.168",
	},
	&fronted.Masquerade{
		Domain:    "www.qld.gov.au",
		IpAddress: "54.182.1.163",
	},
	&fronted.Masquerade{
		Domain:    "www.qld.gov.au",
		IpAddress: "54.182.0.171",
	},
	&fronted.Masquerade{
		Domain:    "www.razoo.com",
		IpAddress: "54.182.1.16",
	},
	&fronted.Masquerade{
		Domain:    "www.razoo.com",
		IpAddress: "204.246.164.101",
	},
	&fronted.Masquerade{
		Domain:    "www.razoo.com",
		IpAddress: "205.251.253.124",
	},
	&fronted.Masquerade{
		Domain:    "www.rexel.nl",
		IpAddress: "205.251.253.181",
	},
	&fronted.Masquerade{
		Domain:    "www.seikyoonline.com",
		IpAddress: "216.137.33.132",
	},
	&fronted.Masquerade{
		Domain:    "www.shopch.jp",
		IpAddress: "216.137.33.78",
	},
	&fronted.Masquerade{
		Domain:    "www.skyprepago.com.br",
		IpAddress: "54.182.0.229",
	},
	&fronted.Masquerade{
		Domain:    "www.skyprepago.com.br",
		IpAddress: "54.239.130.187",
	},
	&fronted.Masquerade{
		Domain:    "www.srv.ygles-test.com",
		IpAddress: "216.137.33.201",
	},
	&fronted.Masquerade{
		Domain:    "www.srv.ygles.com",
		IpAddress: "54.239.130.127",
	},
	&fronted.Masquerade{
		Domain:    "www.srv.ygles.com",
		IpAddress: "54.182.1.156",
	},
	&fronted.Masquerade{
		Domain:    "www.stag.vdna-assets.com",
		IpAddress: "54.182.2.213",
	},
	&fronted.Masquerade{
		Domain:    "www.stocksy.com",
		IpAddress: "54.182.0.62",
	},
	&fronted.Masquerade{
		Domain:    "www.streaming.cdn.delivery.amazonmusic.com",
		IpAddress: "54.182.1.160",
	},
	&fronted.Masquerade{
		Domain:    "www.streaming.cdn.delivery.amazonmusic.com",
		IpAddress: "54.239.130.15",
	},
	&fronted.Masquerade{
		Domain:    "www.tab.com.au",
		IpAddress: "205.251.253.49",
	},
	&fronted.Masquerade{
		Domain:    "www.tab.com.au",
		IpAddress: "54.182.1.236",
	},
	&fronted.Masquerade{
		Domain:    "www.uat.jltinteractive.com",
		IpAddress: "54.182.1.206",
	},
	&fronted.Masquerade{
		Domain:    "www.uat.jltinteractive.com",
		IpAddress: "216.137.33.74",
	},
	&fronted.Masquerade{
		Domain:    "www.ukbusprod.com",
		IpAddress: "54.182.0.232",
	},
	&fronted.Masquerade{
		Domain:    "www.v2.krossover.com",
		IpAddress: "204.246.164.81",
	},
	&fronted.Masquerade{
		Domain:    "www.v2.krossover.com",
		IpAddress: "54.182.0.227",
	},
	&fronted.Masquerade{
		Domain:    "www.voidsphere.jp",
		IpAddress: "205.251.253.229",
	},
	&fronted.Masquerade{
		Domain:    "www.voidsphere.jp",
		IpAddress: "54.239.130.233",
	},
	&fronted.Masquerade{
		Domain:    "www.waze.com",
		IpAddress: "205.251.253.252",
	},
	&fronted.Masquerade{
		Domain:    "www4.credit-suisse.com",
		IpAddress: "205.251.253.77",
	},
	&fronted.Masquerade{
		Domain:    "wylei.com",
		IpAddress: "54.182.1.102",
	},
	&fronted.Masquerade{
		Domain:    "xamarin.com",
		IpAddress: "54.182.1.140",
	},
	&fronted.Masquerade{
		Domain:    "xperialounge.sonymobile.com",
		IpAddress: "54.182.0.169",
	},
	&fronted.Masquerade{
		Domain:    "xperialounge.sonymobile.com",
		IpAddress: "54.239.130.65",
	},
	&fronted.Masquerade{
		Domain:    "xperialounge.sonymobile.com",
		IpAddress: "54.182.1.168",
	},
	&fronted.Masquerade{
		Domain:    "xperialounge.sonymobile.com",
		IpAddress: "54.230.2.77",
	},
	&fronted.Masquerade{
		Domain:    "yldbt.com",
		IpAddress: "54.182.0.94",
	},
	&fronted.Masquerade{
		Domain:    "yldbt.com",
		IpAddress: "216.137.33.117",
	},
	&fronted.Masquerade{
		Domain:    "yumpu.com",
		IpAddress: "205.251.253.167",
	},
	&fronted.Masquerade{
		Domain:    "z-eu.amazon-adsystem.com",
		IpAddress: "54.239.194.8",
	},
	&fronted.Masquerade{
		Domain:    "z-fe.amazon-adsystem.com",
		IpAddress: "54.182.1.237",
	},
	&fronted.Masquerade{
		Domain:    "z-na.amazon-adsystem.com",
		IpAddress: "205.251.253.86",
	},
	&fronted.Masquerade{
		Domain:    "zalora.com",
		IpAddress: "54.239.130.121",
	},
	&fronted.Masquerade{
		Domain:    "zarget.com",
		IpAddress: "54.182.1.161",
	},
	&fronted.Masquerade{
		Domain:    "ziftsolutions.com",
		IpAddress: "54.182.1.190",
	},
	&fronted.Masquerade{
		Domain:    "zillowstatic.com",
		IpAddress: "216.137.33.197",
	},
	&fronted.Masquerade{
		Domain:    "zillowstatic.com",
		IpAddress: "54.182.2.80",
	},
	&fronted.Masquerade{
		Domain:    "zimbra.com",
		IpAddress: "204.246.164.85",
	},
	&fronted.Masquerade{
		Domain:    "zimbra.com",
		IpAddress: "54.182.0.78",
	},
	&fronted.Masquerade{
		Domain:    "zuus.com",
		IpAddress: "54.182.1.65",
	},
	&fronted.Masquerade{
		Domain:    "zype.com",
		IpAddress: "54.182.0.239",
	},
}
