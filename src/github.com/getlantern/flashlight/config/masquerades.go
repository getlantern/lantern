package config

import "github.com/getlantern/fronted"

var defaultTrustedCAs = []*CA{
	&CA{
		CommonName: "VeriSign Class 3 Public Primary Certification Authority - G5",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIE0zCCA7ugAwIBAgIQGNrRniZ96LtKIVjNzGs7SjANBgkqhkiG9w0BAQUFADCB\nyjELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\nExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJp\nU2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxW\nZXJpU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0\naG9yaXR5IC0gRzUwHhcNMDYxMTA4MDAwMDAwWhcNMzYwNzE2MjM1OTU5WjCByjEL\nMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZW\nZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2ln\nbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJp\nU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9y\naXR5IC0gRzUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvJAgIKXo1\nnmAMqudLO07cfLw8RRy7K+D+KQL5VwijZIUVJ/XxrcgxiV0i6CqqpkKzj/i5Vbex\nt0uz/o9+B1fs70PbZmIVYc9gDaTY3vjgw2IIPVQT60nKWVSFJuUrjxuf6/WhkcIz\nSdhDY2pSS9KP6HBRTdGJaXvHcPaz3BJ023tdS1bTlr8Vd6Gw9KIl8q8ckmcY5fQG\nBO+QueQA5N06tRn/Arr0PO7gi+s3i+z016zy9vA9r911kTMZHRxAy3QkGSGT2RT+\nrCpSx4/VBEnkjWNHiDxpg8v+R70rfk/Fla4OndTRQ8Bnc+MUCH7lP59zuDMKz10/\nNIeWiu5T6CUVAgMBAAGjgbIwga8wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8E\nBAMCAQYwbQYIKwYBBQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2UvZ2lmMCEwHzAH\nBgUrDgMCGgQUj+XTGoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDovL2xvZ28udmVy\naXNpZ24uY29tL3ZzbG9nby5naWYwHQYDVR0OBBYEFH/TZafC3ey78DAJ80M5+gKv\nMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQCTJEowX2LP2BqYLz3q3JktvXf2pXkiOOzE\np6B4Eq1iDkVwZMXnl2YtmAl+X6/WzChl8gGqCBpH3vn5fJJaCGkgDdk+bW48DW7Y\n5gaRQBi5+MHt39tBquCWIMnNZBU4gcmU7qKEKQsTb47bDN0lAtukixlE0kF6BWlK\nWE9gyn6CagsCqiUXObXbf+eEZSqVir2G3l6BFoMtEMze/aiCKm0oHw0LxOXnGiYZ\n4fQRbxC1lfznQgUy286dUV4otp6F01vvpX1FQHKOtw5rDgb7MzVIcbidJ4vEZV8N\nhnacRHr2lVz2XTIIM6RUthg/aFzyQkqFOFSDX9HoLPKsEdao7WNq\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "GeoTrust Global CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT\nMRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i\nYWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG\nEwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg\nR2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9\n9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq\nfnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv\niS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU\n1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+\nbw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW\nMPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA\nephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l\nuMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn\nZ57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS\ntQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF\nPseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un\nhw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV\n5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "AddTrust External CA Root",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIENjCCAx6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBvMQswCQYDVQQGEwJTRTEU\nMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFs\nIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290\nMB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowbzELMAkGA1UEBhMCU0Ux\nFDASBgNVBAoTC0FkZFRydXN0IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5h\nbCBUVFAgTmV0d29yazEiMCAGA1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9v\ndDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALf3GjPm8gAELTngTlvt\nH7xsD821+iO2zt6bETOXpClMfZOfvUq8k+0DGuOPz+VtUFrWlymUWoCwSXrbLpX9\nuMq/NzgtHj6RQa1wVsfwTz/oMp50ysiQVOnGXw94nZpAPA6sYapeFI+eh6FqUNzX\nmk6vBbOmcZSccbNQYArHE504B4YCqOmoaSYYkKtMsE8jqzpPhNjfzp/haW+710LX\na0Tkx63ubUFfclpxCDezeWWkWaCUN/cALw3CknLa0Dhy2xSoRcRdKn23tNbE7qzN\nE0S3ySvdQwAl+mG5aWpYIxG3pzOPVnVZ9c0p10a3CitlttNCbxWyuHv77+ldU9U0\nWicCAwEAAaOB3DCB2TAdBgNVHQ4EFgQUrb2YejS0Jvf6xCZU7wO94CTLVBowCwYD\nVR0PBAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wgZkGA1UdIwSBkTCBjoAUrb2YejS0\nJvf6xCZU7wO94CTLVBqhc6RxMG8xCzAJBgNVBAYTAlNFMRQwEgYDVQQKEwtBZGRU\ncnVzdCBBQjEmMCQGA1UECxMdQWRkVHJ1c3QgRXh0ZXJuYWwgVFRQIE5ldHdvcmsx\nIjAgBgNVBAMTGUFkZFRydXN0IEV4dGVybmFsIENBIFJvb3SCAQEwDQYJKoZIhvcN\nAQEFBQADggEBALCb4IUlwtYj4g+WBpKdQZic2YR5gdkeWxQHIzZlj7DYd7usQWxH\nYINRsPkyPef89iYTx4AWpb9a/IfPeHmJIZriTAcKhjW88t5RxNKWt9x+Tu5w/Rw5\n6wwCURQtjr0W4MHfRnXnJK3s9EK0hZNwEGe6nQY1ShjTK3rMUUKhemPR5ruhxSvC\nNr4TDea9Y355e6cJDUCrat2PisP29owaQgVR1EX1n6diIWgVIEM8med8vSTYqZEX\nc4g/VhsxOBi0cQ+azcgOno4uG+GMmIPLHzHxREzGBHNJdmAPx/i9F4BrLunMTA5a\nmnkPIAou1Z5jJh5VkpTYghdae9C8x49OhgQ=\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "Go Daddy Root Certificate Authority - G2",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIBADANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMx\nEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoT\nEUdvRGFkZHkuY29tLCBJbmMuMTEwLwYDVQQDEyhHbyBEYWRkeSBSb290IENlcnRp\nZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIz\nNTk1OVowgYMxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQH\nEwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5LmNvbSwgSW5jLjExMC8GA1UE\nAxMoR28gRGFkZHkgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9xYgjx+lk09xvJGKP3gElY6SKD\nE6bFIEMBO4Tx5oVJnyfq9oQbTqC023CYxzIBsQU+B07u9PpPL1kwIuerGVZr4oAH\n/PMWdYA5UXvl+TW2dE6pjYIT5LY/qQOD+qK+ihVqf94Lw7YZFAXK6sOoBJQ7Rnwy\nDfMAZiLIjWltNowRGLfTshxgtDj6AozO091GB94KPutdfMh8+7ArU6SSYmlRJQVh\nGkSBjCypQ5Yj36w6gZoOKcUcqeldHraenjAKOc7xiID7S13MMuyFYkMlNAJWJwGR\ntDtwKj9useiciAF9n9T521NtYJ2/LOdYq7hfRvzOxBsDPAnrSTFcaUaz4EcCAwEA\nAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE\nFDqahQcQZyi27/a9BUFuIMGU2g/eMA0GCSqGSIb3DQEBCwUAA4IBAQCZ21151fmX\nWWcDYfF+OwYxdS2hII5PZYe096acvNjpL9DbWu7PdIxztDhC2gV7+AJ1uP2lsdeu\n9tfeE8tTEH6KRtGX+rcuKxGrkLAngPnon1rpN5+r5N9ss4UXnT3ZJE95kTXWXwTr\ngIOrmgIttRD02JDHBHNA7XIloKmf7J6raBKZV8aPEjoJpL1E/QYVN8Gb5DKj7Tjo\n2GTzLH4U/ALqn83/B2gX2yKQOC16jdFU8WnjXzPKej17CuPKf1855eJ1usV2GDPO\nLPAvTK33sefOT6jEm0pUBsV/fdUID+Ic/n4XuKxe9tQWskMJDE32p2u0mYRlynqI\n4uJEvlz36hz1\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "DigiCert High Assurance EV Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIQAqxcJmoLQJuPC3nyrkYldzANBgkqhkiG9w0BAQUFADBs\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5j\nZSBFViBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTMxMTExMDAwMDAwMFowbDEL\nMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3\nLmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2Ug\nRVYgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMbM5XPm\n+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRnogocsF9ppkCxxLeyj9CYpKlBWTrT3JTW\nPNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG++MXs2ziS4wblCJEM\nxChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EKmEFB\nIk5lYYeBQVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8VdteZOE3\nhzBWBOURtCmAEvF5OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10aUAsg\nEsxBu24LUTi4S8sCAwEAAaNjMGEwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF\nMAMBAf8wHQYDVR0OBBYEFLE+w2kD+L9HAdSYJhoIAu9jZCvDMB8GA1UdIwQYMBaA\nFLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3DQEBBQUAA4IBAQAcGgaX3Nec\nnzyIZgYIVyHbIUf4KmeqvxgydkAQV8GK83rZEWWONfqe/EW1ntlMMUu4kehDLI6z\neM7b41N5cdblIZQB2lWHmiRk9opmzN6cN82oNLFpmyPInngiK3BD41VHMWEZ71jF\nhS9OMPagMRYjyOfiZRYzy78aG6A9+MpeizGLYAiJLQwGXFK3xPkKmNEVX58Svnw2\nYzi9RKR/5CYrCsSXaQ3pjOLAEFe4yHYSkVXySGnYvCoCWw9E1CAx2/S6cCZdkGCe\nvEsXCS+0yx5DaMkHJ8HSXPfqIbloEpw8nL+e/IBcm2PN7EeqJSdnoDfzAIJ9VNep\n+OkuE6N36B9K\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "thawte Primary Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIEIDCCAwigAwIBAgIQNE7VVyDV7exJ9C/ON9srbTANBgkqhkiG9w0BAQUFADCB\nqTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5jLjEoMCYGA1UECxMf\nQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBEaXZpc2lvbjE4MDYGA1UECxMvKGMpIDIw\nMDYgdGhhd3RlLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxHzAdBgNV\nBAMTFnRoYXd0ZSBQcmltYXJ5IFJvb3QgQ0EwHhcNMDYxMTE3MDAwMDAwWhcNMzYw\nNzE2MjM1OTU5WjCBqTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5j\nLjEoMCYGA1UECxMfQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBEaXZpc2lvbjE4MDYG\nA1UECxMvKGMpIDIwMDYgdGhhd3RlLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNl\nIG9ubHkxHzAdBgNVBAMTFnRoYXd0ZSBQcmltYXJ5IFJvb3QgQ0EwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCsoPD7gFnUnMekz52hWXMJEEUMDSxuaPFs\nW0hoSVk3/AszGcJ3f8wQLZU0HObrTQmnHNK4yZc2AreJ1CRfBsDMRJSUjQJib+ta\n3RGNKJpchJAQeg29dGYvajig4tVUROsdB58Hum/u6f1OCyn1PoSgAfGcq/gcfomk\n6KHYcWUNo1F77rzSImANuVud37r8UVsLr5iy6S7pBOhih94ryNdOwUxkHt3Ph1i6\nSk/KaAcdHJ1KxtUvkcx8cXIcxcBn6zL9yZJclNqFwJu/U30rCfSMnZEfl2pSy94J\nNqR32HuHUETVPm4pafs5SSYeCaWAe0At6+gnhcn+Yf1+5nyXHdWdAgMBAAGjQjBA\nMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBR7W0XP\nr87Lev0xkhpqtvNG61dIUDANBgkqhkiG9w0BAQUFAAOCAQEAeRHAS7ORtvzw6WfU\nDW5FvlXok9LOAz/t2iWwHVfLHjp2oEzsUHboZHIMpKnxuIvW1oeEuzLlQRHAd9mz\nYJ3rG9XRbkREqaYB7FViHXe4XI5ISXycO1cRrK1zN44veFyQaEfZYGDm/Ac9IiAX\nxPcW6cTYcvnIc3zfFi8VqT79aie2oetaupgf1eNNZAqdE8hhuvU5HIe6uL17In/2\n/qxAeeWsEG89jxt5dovEN7MhGITlNgDrYyCZuen+MwS7QcjBAvlEYyCegc5C09Y/\nLHbTY5xZ3Y+m4Q6gLkH3LpVHz7z9M/P2C2F+fpErgUfCJzDupxBdN49cOSvkBPB7\njVaMaA==\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "DigiCert Global Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD\nQTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT\nMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j\nb20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG\n9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB\nCSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97\nnh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt\n43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P\nT19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4\ngdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO\nBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR\nTLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw\nDQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr\nhMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg\n06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF\nPnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls\nYSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk\nCAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=\n-----END CERTIFICATE-----\n",
	},
}

var cloudflareMasquerades = []*frontedMasquerade{}

var cloudfrontMasquerades = []*fronted.Masquerade{
	&fronted.Masquerade{
		Domain:    "101.livere.co.kr",
		IpAddress: "54.182.0.48",
	},
	&fronted.Masquerade{
		Domain:    "Images-na.ssl-images-amazon.com",
		IpAddress: "54.192.0.70",
	},
	&fronted.Masquerade{
		Domain:    "a-ritani.com",
		IpAddress: "54.192.0.2",
	},
	&fronted.Masquerade{
		Domain:    "activerideshop.com",
		IpAddress: "54.192.0.27",
	},
	&fronted.Masquerade{
		Domain:    "ad-lancers.jp",
		IpAddress: "54.182.0.94",
	},
	&fronted.Masquerade{
		Domain:    "adcade.com",
		IpAddress: "54.192.0.81",
	},
	&fronted.Masquerade{
		Domain:    "adcade.com",
		IpAddress: "54.182.0.67",
	},
	&fronted.Masquerade{
		Domain:    "afl.com.au",
		IpAddress: "54.192.0.42",
	},
	&fronted.Masquerade{
		Domain:    "airasia.com",
		IpAddress: "54.182.0.114",
	},
	&fronted.Masquerade{
		Domain:    "api.e1-np.km.playstation.net",
		IpAddress: "54.182.0.57",
	},
	&fronted.Masquerade{
		Domain:    "api.e1-np.km.playstation.net",
		IpAddress: "54.192.0.75",
	},
	&fronted.Masquerade{
		Domain:    "argusmedia.com",
		IpAddress: "54.192.0.52",
	},
	&fronted.Masquerade{
		Domain:    "argusmedia.com",
		IpAddress: "54.182.0.28",
	},
	&fronted.Masquerade{
		Domain:    "assets.bwbx.io",
		IpAddress: "54.182.0.101",
	},
	&fronted.Masquerade{
		Domain:    "assets.bwbx.io",
		IpAddress: "54.192.0.79",
	},
	&fronted.Masquerade{
		Domain:    "barbour-abi.com",
		IpAddress: "54.192.0.38",
	},
	&fronted.Masquerade{
		Domain:    "bibliocommons.com",
		IpAddress: "54.192.0.84",
	},
	&fronted.Masquerade{
		Domain:    "btrll.com",
		IpAddress: "54.182.0.32",
	},
	&fronted.Masquerade{
		Domain:    "bulubox.com",
		IpAddress: "54.182.0.44",
	},
	&fronted.Masquerade{
		Domain:    "buuteeq.com",
		IpAddress: "54.182.0.85",
	},
	&fronted.Masquerade{
		Domain:    "cache.dough.com",
		IpAddress: "54.182.0.13",
	},
	&fronted.Masquerade{
		Domain:    "cdn.avivaworld.com",
		IpAddress: "54.182.0.109",
	},
	&fronted.Masquerade{
		Domain:    "cdn.blitzsport.com",
		IpAddress: "54.182.0.65",
	},
	&fronted.Masquerade{
		Domain:    "cdn.d2gstores.com",
		IpAddress: "54.182.0.34",
	},
	&fronted.Masquerade{
		Domain:    "cdn.elitefts.com",
		IpAddress: "54.192.0.88",
	},
	&fronted.Masquerade{
		Domain:    "cdn.searchspring.net",
		IpAddress: "54.192.0.12",
	},
	&fronted.Masquerade{
		Domain:    "cdn.wdesk.com",
		IpAddress: "54.182.0.79",
	},
	&fronted.Masquerade{
		Domain:    "channeladvisor.com",
		IpAddress: "54.182.0.72",
	},
	&fronted.Masquerade{
		Domain:    "channeladvisor.com",
		IpAddress: "54.192.0.85",
	},
	&fronted.Masquerade{
		Domain:    "classdojo.com",
		IpAddress: "54.182.0.21",
	},
	&fronted.Masquerade{
		Domain:    "client-cf.dropbox.com",
		IpAddress: "54.182.0.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.86",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.0.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.6",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.4",
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
		IpAddress: "54.239.192.9",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.192.0.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.8",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.0.2",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.0.3",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.10",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.10",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.12",
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
		IpAddress: "204.246.164.11",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.9",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.4",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.15",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.12",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.7",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.6",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.13",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.16",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.17",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.35",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.36",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.43",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.37",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.44",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.37",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.38",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.39",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.45",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.36",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.0.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.0.5",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.41",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.49",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.50",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.52",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.45",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.53",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.54",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.48",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.31",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.55",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.46",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.56",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.47",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.42",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.57",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.48",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.49",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.50",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.58",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.52",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.59",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.60",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.54",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.61",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.43",
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
		IpAddress: "204.246.164.55",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.65",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.56",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.66",
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
		IpAddress: "204.246.164.60",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.61",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.62",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.63",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.192.0.72",
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
		IpAddress: "204.246.164.51",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.64",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.64",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.53",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.73",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.44",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.74",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.67",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.75",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.68",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.76",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.69",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.70",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.70",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.78",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.71",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.58",
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
		IpAddress: "54.239.192.83",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.75",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.65",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.59",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.66",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.77",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.85",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.78",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.72",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.87",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.77",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.79",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.88",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.80",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.81",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.86",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.84",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.82",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.83",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.84",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.85",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.76",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.87",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.73",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.57",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.82",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.74",
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
		IpAddress: "204.246.164.14",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.21",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.22",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.23",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.24",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.25",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.18",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.26",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.15",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.16",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.17",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.18",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.27",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.0.3",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.28",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.20",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.21",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.29",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.22",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.30",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.23",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.31",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.24",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.25",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.32",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.19",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.33",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.26",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.34",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.27",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.28",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.35",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.29",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.30",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.38",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.39",
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
		IpAddress: "204.246.164.32",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.33",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.42",
	},
	&fronted.Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.34",
	},
	&fronted.Masquerade{
		Domain:    "cloudfrontdemo.com",
		IpAddress: "54.192.0.40",
	},
	&fronted.Masquerade{
		Domain:    "cloudimg.io",
		IpAddress: "54.192.0.73",
	},
	&fronted.Masquerade{
		Domain:    "croooober.com",
		IpAddress: "54.182.0.59",
	},
	&fronted.Masquerade{
		Domain:    "d1jwpcr0q4pcq0.cloudfront.net",
		IpAddress: "54.182.0.106",
	},
	&fronted.Masquerade{
		Domain:    "dariffnjgq54b.cloudfront.net",
		IpAddress: "54.182.0.49",
	},
	&fronted.Masquerade{
		Domain:    "data.plus.bandainamcoid.com",
		IpAddress: "54.192.0.21",
	},
	&fronted.Masquerade{
		Domain:    "democrats.org",
		IpAddress: "54.192.0.63",
	},
	&fronted.Masquerade{
		Domain:    "dev.sungevity.com",
		IpAddress: "54.192.0.23",
	},
	&fronted.Masquerade{
		Domain:    "developer.sony.com",
		IpAddress: "54.192.0.56",
	},
	&fronted.Masquerade{
		Domain:    "empowernetwork.com",
		IpAddress: "54.182.0.90",
	},
	&fronted.Masquerade{
		Domain:    "enetscores.com",
		IpAddress: "54.182.0.122",
	},
	&fronted.Masquerade{
		Domain:    "fanduel.com",
		IpAddress: "54.182.0.54",
	},
	&fronted.Masquerade{
		Domain:    "figma.com",
		IpAddress: "54.182.0.8",
	},
	&fronted.Masquerade{
		Domain:    "flite.com",
		IpAddress: "54.192.0.78",
	},
	&fronted.Masquerade{
		Domain:    "formisimo.com",
		IpAddress: "54.182.0.64",
	},
	&fronted.Masquerade{
		Domain:    "framework-gb-ssl.cdn.gob.mx",
		IpAddress: "54.192.0.43",
	},
	&fronted.Masquerade{
		Domain:    "ftp.mozilla.org",
		IpAddress: "54.182.0.23",
	},
	&fronted.Masquerade{
		Domain:    "gozoomo.com",
		IpAddress: "54.182.0.61",
	},
	&fronted.Masquerade{
		Domain:    "gp-static.com",
		IpAddress: "54.182.0.31",
	},
	&fronted.Masquerade{
		Domain:    "gr-assets.com",
		IpAddress: "54.182.0.118",
	},
	&fronted.Masquerade{
		Domain:    "housingcdn.com",
		IpAddress: "54.192.0.25",
	},
	&fronted.Masquerade{
		Domain:    "ilearn.robertwalters.com",
		IpAddress: "54.192.0.49",
	},
	&fronted.Masquerade{
		Domain:    "images.insinkerator-worldwide.com",
		IpAddress: "54.192.0.34",
	},
	&fronted.Masquerade{
		Domain:    "jazz.co",
		IpAddress: "54.182.0.22",
	},
	&fronted.Masquerade{
		Domain:    "jivox.com",
		IpAddress: "54.182.0.37",
	},
	&fronted.Masquerade{
		Domain:    "jvidev.com",
		IpAddress: "54.192.0.76",
	},
	&fronted.Masquerade{
		Domain:    "kik.com",
		IpAddress: "54.182.0.102",
	},
	&fronted.Masquerade{
		Domain:    "lafayette148ny.com",
		IpAddress: "54.192.0.22",
	},
	&fronted.Masquerade{
		Domain:    "launchpie.com",
		IpAddress: "54.192.0.80",
	},
	&fronted.Masquerade{
		Domain:    "lgcpm.com",
		IpAddress: "54.182.0.117",
	},
	&fronted.Masquerade{
		Domain:    "litmuscdn.com",
		IpAddress: "54.192.0.48",
	},
	&fronted.Masquerade{
		Domain:    "mail.mailgarant.nl",
		IpAddress: "54.182.0.88",
	},
	&fronted.Masquerade{
		Domain:    "manta-r3.com",
		IpAddress: "54.182.0.35",
	},
	&fronted.Masquerade{
		Domain:    "massrelevance.com",
		IpAddress: "54.182.0.112",
	},
	&fronted.Masquerade{
		Domain:    "media.healthdirect.org.au",
		IpAddress: "54.182.0.45",
	},
	&fronted.Masquerade{
		Domain:    "medibang.com",
		IpAddress: "54.192.0.28",
	},
	&fronted.Masquerade{
		Domain:    "mindflash.com",
		IpAddress: "54.182.0.99",
	},
	&fronted.Masquerade{
		Domain:    "mobilerq.com",
		IpAddress: "54.192.0.6",
	},
	&fronted.Masquerade{
		Domain:    "mtstatic.com",
		IpAddress: "54.182.0.89",
	},
	&fronted.Masquerade{
		Domain:    "notonthehighstreet.com",
		IpAddress: "54.192.0.50",
	},
	&fronted.Masquerade{
		Domain:    "officeworks.com.au",
		IpAddress: "54.192.0.87",
	},
	&fronted.Masquerade{
		Domain:    "order.hbonow.com",
		IpAddress: "54.182.0.40",
	},
	&fronted.Masquerade{
		Domain:    "origin-preprod.roberthalf.com",
		IpAddress: "54.192.0.68",
	},
	&fronted.Masquerade{
		Domain:    "payscale.com",
		IpAddress: "54.192.0.15",
	},
	&fronted.Masquerade{
		Domain:    "salesforcesos.com",
		IpAddress: "54.192.0.62",
	},
	&fronted.Masquerade{
		Domain:    "samsungcloudsolution.com",
		IpAddress: "54.182.0.42",
	},
	&fronted.Masquerade{
		Domain:    "sanoma.com",
		IpAddress: "54.182.0.19",
	},
	&fronted.Masquerade{
		Domain:    "segment.io",
		IpAddress: "54.192.0.45",
	},
	&fronted.Masquerade{
		Domain:    "segment.io",
		IpAddress: "54.182.0.7",
	},
	&fronted.Masquerade{
		Domain:    "servicechannel.com",
		IpAddress: "54.192.0.67",
	},
	&fronted.Masquerade{
		Domain:    "shopstyle.com",
		IpAddress: "54.182.0.68",
	},
	&fronted.Masquerade{
		Domain:    "sketchup.com",
		IpAddress: "54.192.0.71",
	},
	&fronted.Masquerade{
		Domain:    "sling.com",
		IpAddress: "54.192.0.59",
	},
	&fronted.Masquerade{
		Domain:    "smartica.jp",
		IpAddress: "54.182.0.9",
	},
	&fronted.Masquerade{
		Domain:    "smartrecruiters.com",
		IpAddress: "54.182.0.10",
	},
	&fronted.Masquerade{
		Domain:    "smtown.com",
		IpAddress: "54.192.0.86",
	},
	&fronted.Masquerade{
		Domain:    "socialpointgames.com",
		IpAddress: "54.182.0.81",
	},
	&fronted.Masquerade{
		Domain:    "sonicwall.com",
		IpAddress: "54.182.0.5",
	},
	&fronted.Masquerade{
		Domain:    "sonicwall.com",
		IpAddress: "54.192.0.39",
	},
	&fronted.Masquerade{
		Domain:    "sportsyapper.com",
		IpAddress: "54.182.0.63",
	},
	&fronted.Masquerade{
		Domain:    "sso.ng",
		IpAddress: "54.182.0.71",
	},
	&fronted.Masquerade{
		Domain:    "stage01.publish.adobe.com",
		IpAddress: "54.182.0.41",
	},
	&fronted.Masquerade{
		Domain:    "stage02.publish.adobe.com",
		IpAddress: "54.192.0.77",
	},
	&fronted.Masquerade{
		Domain:    "staging.hairessentials.com",
		IpAddress: "54.182.0.14",
	},
	&fronted.Masquerade{
		Domain:    "staticapp.icpsc.com",
		IpAddress: "54.182.0.108",
	},
	&fronted.Masquerade{
		Domain:    "sundaysky.com",
		IpAddress: "54.182.0.53",
	},
	&fronted.Masquerade{
		Domain:    "tango.me",
		IpAddress: "54.182.0.11",
	},
	&fronted.Masquerade{
		Domain:    "tapad.com",
		IpAddress: "54.182.0.83",
	},
	&fronted.Masquerade{
		Domain:    "teambuilder.heroesofthestorm.com",
		IpAddress: "54.192.0.54",
	},
	&fronted.Masquerade{
		Domain:    "theknot.com",
		IpAddress: "54.182.0.39",
	},
	&fronted.Masquerade{
		Domain:    "theknot.com",
		IpAddress: "54.182.0.87",
	},
	&fronted.Masquerade{
		Domain:    "toons.tv",
		IpAddress: "54.182.0.92",
	},
	&fronted.Masquerade{
		Domain:    "tstatic.eu",
		IpAddress: "54.182.0.116",
	},
	&fronted.Masquerade{
		Domain:    "twinehealth.com",
		IpAddress: "54.192.0.55",
	},
	&fronted.Masquerade{
		Domain:    "ubcdn.co",
		IpAddress: "54.182.0.24",
	},
	&fronted.Masquerade{
		Domain:    "umbel.com",
		IpAddress: "54.182.0.55",
	},
	&fronted.Masquerade{
		Domain:    "useiti.doi.gov",
		IpAddress: "54.192.0.58",
	},
	&fronted.Masquerade{
		Domain:    "uswitch.com",
		IpAddress: "54.182.0.52",
	},
	&fronted.Masquerade{
		Domain:    "vdna-assets.com",
		IpAddress: "54.182.0.30",
	},
	&fronted.Masquerade{
		Domain:    "versal.com",
		IpAddress: "54.192.0.29",
	},
	&fronted.Masquerade{
		Domain:    "vmweb.net",
		IpAddress: "54.192.0.35",
	},
	&fronted.Masquerade{
		Domain:    "webcast.sambatech.com.br",
		IpAddress: "54.182.0.93",
	},
	&fronted.Masquerade{
		Domain:    "www.appia.com",
		IpAddress: "54.192.0.83",
	},
	&fronted.Masquerade{
		Domain:    "www.ccpsx.com",
		IpAddress: "54.182.0.75",
	},
	&fronted.Masquerade{
		Domain:    "www.fmicassets.com",
		IpAddress: "54.182.0.47",
	},
	&fronted.Masquerade{
		Domain:    "www.knowledgevision.com",
		IpAddress: "54.192.0.13",
	},
	&fronted.Masquerade{
		Domain:    "www.ksmobile.com",
		IpAddress: "54.182.0.98",
	},
	&fronted.Masquerade{
		Domain:    "www.mapnwea.org",
		IpAddress: "54.192.0.10",
	},
	&fronted.Masquerade{
		Domain:    "www.mobizen.com",
		IpAddress: "54.182.0.77",
	},
	&fronted.Masquerade{
		Domain:    "www.netmarble.net",
		IpAddress: "54.192.0.16",
	},
	&fronted.Masquerade{
		Domain:    "www.nissan.square-root.com",
		IpAddress: "54.192.0.53",
	},
	&fronted.Masquerade{
		Domain:    "www.nissan.square-root.com",
		IpAddress: "54.182.0.29",
	},
	&fronted.Masquerade{
		Domain:    "www.presidentialinnovationfellows.gov",
		IpAddress: "54.182.0.78",
	},
	&fronted.Masquerade{
		Domain:    "www.samsungapps.com",
		IpAddress: "54.192.0.18",
	},
	&fronted.Masquerade{
		Domain:    "www.samsungknowledge.com",
		IpAddress: "54.192.0.60",
	},
	&fronted.Masquerade{
		Domain:    "www.secb2b.com",
		IpAddress: "54.192.0.51",
	},
	&fronted.Masquerade{
		Domain:    "www.sodexomyway.com",
		IpAddress: "54.182.0.66",
	},
	&fronted.Masquerade{
		Domain:    "www.softcoin.com",
		IpAddress: "54.182.0.25",
	},
	&fronted.Masquerade{
		Domain:    "www.tag-team-app.com",
		IpAddress: "54.192.0.44",
	},
	&fronted.Masquerade{
		Domain:    "www.tenki-yoho.jp",
		IpAddress: "54.192.0.5",
	},
	&fronted.Masquerade{
		Domain:    "www.trafalgar.com",
		IpAddress: "54.192.0.66",
	},
	&fronted.Masquerade{
		Domain:    "www.w55c.net",
		IpAddress: "54.192.0.14",
	},
	&fronted.Masquerade{
		Domain:    "z-in.amazon-adsystem.com",
		IpAddress: "54.182.0.36",
	},
	&fronted.Masquerade{
		Domain:    "ziftsolutions.com",
		IpAddress: "54.182.0.20",
	},
}
