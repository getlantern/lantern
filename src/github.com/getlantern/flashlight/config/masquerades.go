package config

import "github.com/getlantern/fronted"

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
		CommonName: "DigiCert High Assurance EV Root CA",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIQAqxcJmoLQJuPC3nyrkYldzANBgkqhkiG9w0BAQUFADBs\nMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\nd3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5j\nZSBFViBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTMxMTExMDAwMDAwMFowbDEL\nMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3\nLmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2Ug\nRVYgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMbM5XPm\n+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRnogocsF9ppkCxxLeyj9CYpKlBWTrT3JTW\nPNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG++MXs2ziS4wblCJEM\nxChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EKmEFB\nIk5lYYeBQVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8VdteZOE3\nhzBWBOURtCmAEvF5OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10aUAsg\nEsxBu24LUTi4S8sCAwEAAaNjMGEwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF\nMAMBAf8wHQYDVR0OBBYEFLE+w2kD+L9HAdSYJhoIAu9jZCvDMB8GA1UdIwQYMBaA\nFLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3DQEBBQUAA4IBAQAcGgaX3Nec\nnzyIZgYIVyHbIUf4KmeqvxgydkAQV8GK83rZEWWONfqe/EW1ntlMMUu4kehDLI6z\neM7b41N5cdblIZQB2lWHmiRk9opmzN6cN82oNLFpmyPInngiK3BD41VHMWEZ71jF\nhS9OMPagMRYjyOfiZRYzy78aG6A9+MpeizGLYAiJLQwGXFK3xPkKmNEVX58Svnw2\nYzi9RKR/5CYrCsSXaQ3pjOLAEFe4yHYSkVXySGnYvCoCWw9E1CAx2/S6cCZdkGCe\nvEsXCS+0yx5DaMkHJ8HSXPfqIbloEpw8nL+e/IBcm2PN7EeqJSdnoDfzAIJ9VNep\n+OkuE6N36B9K\n-----END CERTIFICATE-----\n",
	},
	&CA{
		CommonName: "COMODO RSA Certification Authority",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIF2DCCA8CgAwIBAgIQTKr5yttjb+Af907YWwOGnTANBgkqhkiG9w0BAQwFADCB\nhTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4G\nA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNV\nBAMTIkNPTU9ETyBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAwMTE5\nMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCBhTELMAkGA1UEBhMCR0IxGzAZBgNVBAgT\nEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMR\nQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBSU0EgQ2VydGlmaWNh\ndGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCR\n6FSS0gpWsawNJN3Fz0RndJkrN6N9I3AAcbxT38T6KhKPS38QVr2fcHK3YX/JSw8X\npz3jsARh7v8Rl8f0hj4K+j5c+ZPmNHrZFGvnnLOFoIJ6dq9xkNfs/Q36nGz637CC\n9BR++b7Epi9Pf5l/tfxnQ3K9DADWietrLNPtj5gcFKt+5eNu/Nio5JIk2kNrYrhV\n/erBvGy2i/MOjZrkm2xpmfh4SDBF1a3hDTxFYPwyllEnvGfDyi62a+pGx8cgoLEf\nZd5ICLqkTqnyg0Y3hOvozIFIQ2dOciqbXL1MGyiKXCJ7tKuY2e7gUYPDCUZObT6Z\n+pUX2nwzV0E8jVHtC7ZcryxjGt9XyD+86V3Em69FmeKjWiS0uqlWPc9vqv9JWL7w\nqP/0uK3pN/u6uPQLOvnoQ0IeidiEyxPx2bvhiWC4jChWrBQdnArncevPDt09qZah\nSL0896+1DSJMwBGB7FY79tOi4lu3sgQiUpWAk2nojkxl8ZEDLXB0AuqLZxUpaVIC\nu9ffUGpVRr+goyhhf3DQw6KqLCGqR84onAZFdr+CGCe01a60y1Dma/RMhnEw6abf\nFobg2P9A3fvQQoh/ozM6LlweQRGBY84YcWsr7KaKtzFcOmpH4MN5WdYgGq/yapiq\ncrxXStJLnbsQ/LBMQeXtHT1eKJ2czL+zUdqnR+WEUwIDAQABo0IwQDAdBgNVHQ4E\nFgQUu69+Aj36pvE8hI6t7jiY7NkyMtQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB\n/wQFMAMBAf8wDQYJKoZIhvcNAQEMBQADggIBAArx1UaEt65Ru2yyTUEUAJNMnMvl\nwFTPoCWOAvn9sKIN9SCYPBMtrFaisNZ+EZLpLrqeLppysb0ZRGxhNaKatBYSaVqM\n4dc+pBroLwP0rmEdEBsqpIt6xf4FpuHA1sj+nq6PK7o9mfjYcwlYRm6mnPTXJ9OV\n2jeDchzTc+CiR5kDOF3VSXkAKRzH7JsgHAckaVd4sjn8OoSgtZx8jb8uk2Intzna\nFxiuvTwJaP+EmzzV1gsD41eeFPfR60/IvYcjt7ZJQ3mFXLrrkguhxuhoqEwWsRqZ\nCuhTLJK7oQkYdQxlqHvLI7cawiiFwxv/0Cti76R7CZGYZ4wUAc1oBmpjIXUDgIiK\nboHGhfKppC3n9KUkEEeDys30jXlYsQab5xoq2Z0B15R97QNKyvDb6KkBPvVWmcke\njkk9u+UJueBPSZI9FoJAzMxZxuY67RIuaTxslbH9qh17f4a+Hg4yRvv7E491f0yL\nS0Zj/gA0QHDBw7mh3aZw4gSzQbzpgJHqZJx64SIDqZxubw5lT2yHh17zbqD5daWb\nQOhTsiedSrnAdyGN/4fy3ryM7xfft0kL0fJuMAsaDk527RH89elWsn2/x20Kk4yl\n0MC2Hb46TpSi125sC8KKfPog88Tk5c0NqMuRkrF8hey1FGlmDoLnzc7ILaZRfyHB\nNVOFBkpdn627G190\n-----END CERTIFICATE-----\n",
	},
}

var cloudflareMasquerades = []*fronted.Masquerade{
	&fronted.Masquerade{
		Domain:    "2ch.hk",
		IpAddress: "162.159.253.5",
	},
	&fronted.Masquerade{
		Domain:    "abs-cbnnews.com",
		IpAddress: "104.16.25.177",
	},
	&fronted.Masquerade{
		Domain:    "addmefast.com",
		IpAddress: "198.41.190.157",
	},
	&fronted.Masquerade{
		Domain:    "affiliatetechnology.com",
		IpAddress: "198.41.184.52",
	},
	&fronted.Masquerade{
		Domain:    "al-akhbar.com",
		IpAddress: "162.159.243.97",
	},
	&fronted.Masquerade{
		Domain:    "amino.dk",
		IpAddress: "198.41.189.121",
	},
	&fronted.Masquerade{
		Domain:    "aqarcity.com",
		IpAddress: "198.41.206.196",
	},
	&fronted.Masquerade{
		Domain:    "arabseed.com",
		IpAddress: "198.41.188.132",
	},
	&fronted.Masquerade{
		Domain:    "arageek.com",
		IpAddress: "198.41.205.85",
	},
	&fronted.Masquerade{
		Domain:    "avpixlat.info",
		IpAddress: "198.41.185.144",
	},
	&fronted.Masquerade{
		Domain:    "baiscopelk.com",
		IpAddress: "162.159.243.181",
	},
	&fronted.Masquerade{
		Domain:    "bancdebinary.com",
		IpAddress: "190.93.246.89",
	},
	&fronted.Masquerade{
		Domain:    "bezuzyteczna.pl",
		IpAddress: "198.41.178.171",
	},
	&fronted.Masquerade{
		Domain:    "bikroy.com",
		IpAddress: "104.16.25.214",
	},
	&fronted.Masquerade{
		Domain:    "bukkit.org",
		IpAddress: "141.101.114.100",
	},
	&fronted.Masquerade{
		Domain:    "cloudify.cc",
		IpAddress: "162.159.252.62",
	},
	&fronted.Masquerade{
		Domain:    "col3negoriginal.lk",
		IpAddress: "141.101.112.10",
	},
	&fronted.Masquerade{
		Domain:    "conservativetribune.com",
		IpAddress: "104.20.11.207",
	},
	&fronted.Masquerade{
		Domain:    "cuevana2.tv",
		IpAddress: "162.159.242.105",
	},
	&fronted.Masquerade{
		Domain:    "culturacolectiva.com",
		IpAddress: "198.41.191.73",
	},
	&fronted.Masquerade{
		Domain:    "curse.com",
		IpAddress: "141.101.114.102",
	},
	&fronted.Masquerade{
		Domain:    "cursecdn.com",
		IpAddress: "198.41.209.101",
	},
	&fronted.Masquerade{
		Domain:    "damn.com",
		IpAddress: "104.20.28.213",
	},
	&fronted.Masquerade{
		Domain:    "diablofans.com",
		IpAddress: "198.41.209.101",
	},
	&fronted.Masquerade{
		Domain:    "dostor.org",
		IpAddress: "104.20.12.195",
	},
	&fronted.Masquerade{
		Domain:    "dpstream.net",
		IpAddress: "198.41.191.151",
	},
	&fronted.Masquerade{
		Domain:    "e-cigarette-forum.com",
		IpAddress: "104.20.0.179",
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
		Domain:    "elhacker.net",
		IpAddress: "190.93.253.63",
	},
	&fronted.Masquerade{
		Domain:    "eurostreaming.tv",
		IpAddress: "190.93.240.108",
	},
	&fronted.Masquerade{
		Domain:    "famousbirthdays.com",
		IpAddress: "190.93.244.80",
	},
	&fronted.Masquerade{
		Domain:    "forexpeacearmy.com",
		IpAddress: "141.101.123.28",
	},
	&fronted.Masquerade{
		Domain:    "freenode.net",
		IpAddress: "162.159.249.27",
	},
	&fronted.Masquerade{
		Domain:    "frontpage.fok.nl",
		IpAddress: "104.20.9.180",
	},
	&fronted.Masquerade{
		Domain:    "gameskwala.com",
		IpAddress: "162.159.241.227",
	},
	&fronted.Masquerade{
		Domain:    "gcflearnfree.org",
		IpAddress: "190.93.240.72",
	},
	&fronted.Masquerade{
		Domain:    "geo.tv",
		IpAddress: "141.101.115.11",
	},
	&fronted.Masquerade{
		Domain:    "ghost.org",
		IpAddress: "141.101.115.19",
	},
	&fronted.Masquerade{
		Domain:    "gigacircle.com",
		IpAddress: "104.16.31.35",
	},
	&fronted.Masquerade{
		Domain:    "glamora.ma",
		IpAddress: "162.159.249.147",
	},
	&fronted.Masquerade{
		Domain:    "goodsearch.com",
		IpAddress: "141.101.123.98",
	},
	&fronted.Masquerade{
		Domain:    "gtspirit.com",
		IpAddress: "198.41.206.160",
	},
	&fronted.Masquerade{
		Domain:    "gumroad.com",
		IpAddress: "108.162.200.110",
	},
	&fronted.Masquerade{
		Domain:    "hackforums.net",
		IpAddress: "141.101.121.9",
	},
	&fronted.Masquerade{
		Domain:    "hibapress.com",
		IpAddress: "162.159.244.178",
	},
	&fronted.Masquerade{
		Domain:    "i-fit.com.tw",
		IpAddress: "108.162.201.108",
	},
	&fronted.Masquerade{
		Domain:    "imgflip.com",
		IpAddress: "190.93.246.142",
	},
	&fronted.Masquerade{
		Domain:    "imsuccesscenter.com",
		IpAddress: "67.225.226.131",
	},
	&fronted.Masquerade{
		Domain:    "inforesist.org",
		IpAddress: "108.162.205.29",
	},
	&fronted.Masquerade{
		Domain:    "ipiccy.com",
		IpAddress: "190.93.243.33",
	},
	&fronted.Masquerade{
		Domain:    "juksy.com",
		IpAddress: "162.159.240.29",
	},
	&fronted.Masquerade{
		Domain:    "kidsactivitiesblog.com",
		IpAddress: "198.41.249.230",
	},
	&fronted.Masquerade{
		Domain:    "klix.ba",
		IpAddress: "141.101.112.88",
	},
	&fronted.Masquerade{
		Domain:    "klout.com",
		IpAddress: "190.93.246.193",
	},
	&fronted.Masquerade{
		Domain:    "lankacnews.com",
		IpAddress: "198.41.205.246",
	},
	&fronted.Masquerade{
		Domain:    "lbcgroup.tv",
		IpAddress: "190.93.243.50",
	},
	&fronted.Masquerade{
		Domain:    "lifebuzz.com",
		IpAddress: "104.16.23.166",
	},
	&fronted.Masquerade{
		Domain:    "likes.com",
		IpAddress: "141.101.115.34",
	},
	&fronted.Masquerade{
		Domain:    "lowendbox.com",
		IpAddress: "104.20.10.210",
	},
	&fronted.Masquerade{
		Domain:    "lowendtalk.com",
		IpAddress: "104.20.17.210",
	},
	&fronted.Masquerade{
		Domain:    "maannews.net",
		IpAddress: "198.41.178.195",
	},
	&fronted.Masquerade{
		Domain:    "macworld.co.uk",
		IpAddress: "104.16.10.54",
	},
	&fronted.Masquerade{
		Domain:    "maplestage.com",
		IpAddress: "162.159.255.194",
	},
	&fronted.Masquerade{
		Domain:    "marunadanmalayali.com",
		IpAddress: "198.41.204.108",
	},
	&fronted.Masquerade{
		Domain:    "matchesfashion.com",
		IpAddress: "198.41.184.14",
	},
	&fronted.Masquerade{
		Domain:    "media-fire.org",
		IpAddress: "198.41.184.89",
	},
	&fronted.Masquerade{
		Domain:    "mg.co.za",
		IpAddress: "198.41.207.142",
	},
	&fronted.Masquerade{
		Domain:    "mmo-champion.com",
		IpAddress: "190.93.246.118",
	},
	&fronted.Masquerade{
		Domain:    "mo.gov",
		IpAddress: "199.83.134.59",
	},
	&fronted.Masquerade{
		Domain:    "moneyplatform.biz",
		IpAddress: "108.162.201.215",
	},
	&fronted.Masquerade{
		Domain:    "mylikes.com",
		IpAddress: "190.93.246.37",
	},
	&fronted.Masquerade{
		Domain:    "naijaloaded.com.ng",
		IpAddress: "141.101.125.140",
	},
	&fronted.Masquerade{
		Domain:    "naosalvo.com.br",
		IpAddress: "162.159.246.196",
	},
	&fronted.Masquerade{
		Domain:    "network-tools.com",
		IpAddress: "141.101.123.110",
	},
	&fronted.Masquerade{
		Domain:    "noticiaaldia.com",
		IpAddress: "198.41.180.92",
	},
	&fronted.Masquerade{
		Domain:    "ojooo.com",
		IpAddress: "198.41.190.230",
	},
	&fronted.Masquerade{
		Domain:    "oneplus.net",
		IpAddress: "198.41.185.162",
	},
	&fronted.Masquerade{
		Domain:    "opensoftwareupdater.com",
		IpAddress: "104.16.35.79",
	},
	&fronted.Masquerade{
		Domain:    "pcadvisor.co.uk",
		IpAddress: "104.16.26.51",
	},
	&fronted.Masquerade{
		Domain:    "pelis24.com",
		IpAddress: "190.93.242.104",
	},
	&fronted.Masquerade{
		Domain:    "photoyoum7.com",
		IpAddress: "104.16.6.117",
	},
	&fronted.Masquerade{
		Domain:    "pijamasurf.com",
		IpAddress: "162.159.241.249",
	},
	&fronted.Masquerade{
		Domain:    "planetminecraft.com",
		IpAddress: "141.101.113.126",
	},
	&fronted.Masquerade{
		Domain:    "post852.com",
		IpAddress: "104.20.18.192",
	},
	&fronted.Masquerade{
		Domain:    "propakistani.pk",
		IpAddress: "162.159.243.228",
	},
	&fronted.Masquerade{
		Domain:    "r10.net",
		IpAddress: "104.20.24.135",
	},
	&fronted.Masquerade{
		Domain:    "rsw-systems.com",
		IpAddress: "104.20.20.116",
	},
	&fronted.Masquerade{
		Domain:    "rudaw.net",
		IpAddress: "190.93.241.83",
	},
	&fronted.Masquerade{
		Domain:    "rusvesna.su",
		IpAddress: "162.159.252.221",
	},
	&fronted.Masquerade{
		Domain:    "sergey-mavrodi.com",
		IpAddress: "104.20.8.247",
	},
	&fronted.Masquerade{
		Domain:    "sergeymavrodi.com",
		IpAddress: "104.20.13.247",
	},
	&fronted.Masquerade{
		Domain:    "sinchew.com.my",
		IpAddress: "141.101.121.131",
	},
	&fronted.Masquerade{
		Domain:    "skladchik.com",
		IpAddress: "104.20.15.42",
	},
	&fronted.Masquerade{
		Domain:    "smittenkitchen.com",
		IpAddress: "190.93.240.139",
	},
	&fronted.Masquerade{
		Domain:    "smosh.com",
		IpAddress: "162.159.253.34",
	},
	&fronted.Masquerade{
		Domain:    "smotrisport.tv",
		IpAddress: "141.101.121.222",
	},
	&fronted.Masquerade{
		Domain:    "snapengage.com",
		IpAddress: "190.93.242.132",
	},
	&fronted.Masquerade{
		Domain:    "sportbox.az",
		IpAddress: "108.162.205.43",
	},
	&fronted.Masquerade{
		Domain:    "stadt-bremerhaven.de",
		IpAddress: "198.41.186.16",
	},
	&fronted.Masquerade{
		Domain:    "theiconic.com.au",
		IpAddress: "198.41.186.186",
	},
	&fronted.Masquerade{
		Domain:    "themattwalshblog.com",
		IpAddress: "108.162.203.50",
	},
	&fronted.Masquerade{
		Domain:    "themindunleashed.org",
		IpAddress: "108.162.201.137",
	},
	&fronted.Masquerade{
		Domain:    "thenationonlineng.net",
		IpAddress: "162.159.254.179",
	},
	&fronted.Masquerade{
		Domain:    "thenews.com.pk",
		IpAddress: "104.16.31.122",
	},
	&fronted.Masquerade{
		Domain:    "therakyatpost.com",
		IpAddress: "198.41.185.177",
	},
	&fronted.Masquerade{
		Domain:    "tribalfootball.com",
		IpAddress: "141.101.112.4",
	},
	&fronted.Masquerade{
		Domain:    "ummat.net",
		IpAddress: "108.162.207.43",
	},
	&fronted.Masquerade{
		Domain:    "uploadboy.com",
		IpAddress: "141.101.125.100",
	},
	&fronted.Masquerade{
		Domain:    "uptobox.com",
		IpAddress: "198.41.189.178",
	},
	&fronted.Masquerade{
		Domain:    "vetogate.com",
		IpAddress: "190.93.243.58",
	},
	&fronted.Masquerade{
		Domain:    "videomega.tv",
		IpAddress: "162.159.254.155",
	},
	&fronted.Masquerade{
		Domain:    "videoyoum7.com",
		IpAddress: "104.16.21.116",
	},
	&fronted.Masquerade{
		Domain:    "watch32.com",
		IpAddress: "162.159.248.45",
	},
	&fronted.Masquerade{
		Domain:    "weknowmemes.com",
		IpAddress: "162.159.243.155",
	},
	&fronted.Masquerade{
		Domain:    "what.cd",
		IpAddress: "198.41.184.107",
	},
	&fronted.Masquerade{
		Domain:    "wholehk.com",
		IpAddress: "198.41.205.227",
	},
	&fronted.Masquerade{
		Domain:    "wikiwiki.jp",
		IpAddress: "190.93.241.68",
	},
	&fronted.Masquerade{
		Domain:    "www.ahnegao.com.br",
		IpAddress: "108.162.204.162",
	},
	&fronted.Masquerade{
		Domain:    "www.alweeam.com.sa",
		IpAddress: "198.41.187.77",
	},
	&fronted.Masquerade{
		Domain:    "www.animenewsnetwork.com",
		IpAddress: "198.41.176.81",
	},
	&fronted.Masquerade{
		Domain:    "www.bulletproofexec.com",
		IpAddress: "198.41.187.55",
	},
	&fronted.Masquerade{
		Domain:    "www.caracoltv.com",
		IpAddress: "190.93.241.64",
	},
	&fronted.Masquerade{
		Domain:    "www.cbinsights.com",
		IpAddress: "162.159.249.250",
	},
	&fronted.Masquerade{
		Domain:    "www.coinbase.com",
		IpAddress: "104.16.8.251",
	},
	&fronted.Masquerade{
		Domain:    "www.davidicke.com",
		IpAddress: "198.41.186.87",
	},
	&fronted.Masquerade{
		Domain:    "www.diggita.it",
		IpAddress: "162.159.244.162",
	},
	&fronted.Masquerade{
		Domain:    "www.digitalocean.com",
		IpAddress: "104.16.25.4",
	},
	&fronted.Masquerade{
		Domain:    "www.forosdelweb.com",
		IpAddress: "141.101.121.37",
	},
	&fronted.Masquerade{
		Domain:    "www.g2a.com",
		IpAddress: "141.101.113.180",
	},
	&fronted.Masquerade{
		Domain:    "www.geenstijl.nl",
		IpAddress: "198.41.181.215",
	},
	&fronted.Masquerade{
		Domain:    "www.hespress.com",
		IpAddress: "162.159.252.98",
	},
	&fronted.Masquerade{
		Domain:    "www.huaweidevice.co.in",
		IpAddress: "198.41.205.132",
	},
	&fronted.Masquerade{
		Domain:    "www.jotform.com",
		IpAddress: "141.101.121.43",
	},
	&fronted.Masquerade{
		Domain:    "www.levelup.com",
		IpAddress: "162.159.253.190",
	},
	&fronted.Masquerade{
		Domain:    "www.manatelugumovies.net",
		IpAddress: "162.159.245.168",
	},
	&fronted.Masquerade{
		Domain:    "www.mobofree.com",
		IpAddress: "198.41.247.219",
	},
	&fronted.Masquerade{
		Domain:    "www.modernghana.com",
		IpAddress: "162.159.253.104",
	},
	&fronted.Masquerade{
		Domain:    "www.newgrounds.com",
		IpAddress: "104.20.29.55",
	},
	&fronted.Masquerade{
		Domain:    "www.odesk.com",
		IpAddress: "190.93.246.237",
	},
	&fronted.Masquerade{
		Domain:    "www.pdftoword.com",
		IpAddress: "184.73.209.201",
	},
	&fronted.Masquerade{
		Domain:    "www.primewire.ag",
		IpAddress: "104.20.7.77",
	},
	&fronted.Masquerade{
		Domain:    "www.quadratin.com.mx",
		IpAddress: "162.159.253.44",
	},
	&fronted.Masquerade{
		Domain:    "www.shortlist.com",
		IpAddress: "141.101.123.31",
	},
	&fronted.Masquerade{
		Domain:    "www.sm3na.com",
		IpAddress: "198.41.178.172",
	},
	&fronted.Masquerade{
		Domain:    "www.stoiximan.gr",
		IpAddress: "190.93.240.131",
	},
	&fronted.Masquerade{
		Domain:    "www.techdirt.com",
		IpAddress: "162.159.244.199",
	},
	&fronted.Masquerade{
		Domain:    "www.traidnt.net",
		IpAddress: "141.101.112.65",
	},
	&fronted.Masquerade{
		Domain:    "www.vavel.com",
		IpAddress: "190.93.241.103",
	},
	&fronted.Masquerade{
		Domain:    "www.zaman.com.tr",
		IpAddress: "141.101.114.170",
	},
	&fronted.Masquerade{
		Domain:    "www.zopim.com",
		IpAddress: "190.93.241.200",
	},
	&fronted.Masquerade{
		Domain:    "www.zumba.com",
		IpAddress: "190.93.247.77",
	},
	&fronted.Masquerade{
		Domain:    "x-kom.pl",
		IpAddress: "104.20.28.24",
	},
	&fronted.Masquerade{
		Domain:    "xat.com",
		IpAddress: "190.93.243.81",
	},
	&fronted.Masquerade{
		Domain:    "zerozero.pt",
		IpAddress: "198.41.185.108",
	},
	&fronted.Masquerade{
		Domain:    "zwaar.net",
		IpAddress: "162.159.242.22",
	},
}
