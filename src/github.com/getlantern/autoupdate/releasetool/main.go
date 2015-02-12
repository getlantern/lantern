package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strconv"

	"github.com/getlantern/autoupdate/releasetool/client"
	"github.com/getlantern/go-update"
	"github.com/getlantern/yaml"
)

const (
	configFile = "equinox.yaml"
)

var (
	flagConfigFile = flag.String("config", configFile, "Configuration file.")
	flagSource     = flag.String("source", "", "Source binary file.")
	flagChannel    = flag.String("channel", "stable", "Release channel.")
	flagVersion    = flag.Int("version", -1, "Version number.")
	flagArch       = flag.String("arch", "", "Build architecture. (amd64|386|arm)")
	flagOS         = flag.String("os", "", "Operating system. (linux|windows|darwin)")
)

func main() {
	var fp *os.File
	var cfg client.Config
	var err error
	var buf []byte

	// Parsing flags
	flag.Parse()

	// Validating version.
	if *flagVersion < 0 {
		log.Fatal("Version must be a positive integer (-version).")
	}

	// Validating arch.
	switch *flagArch {
	case "amd64", "386":
		// OK.
	default:
		log.Fatal("Missing a valid build architecture (-arch).")
	}

	// Validating OS.
	switch *flagOS {
	case "linux", "darwin", "windows":
		// OK.
	default:
		log.Fatal("Missing a valid build target operating system (-os).")
	}

	// Opening config file.
	if fp, err = os.Open(*flagConfigFile); err != nil {
		log.Fatal(fmt.Errorf("Could not open config file: %q", err))
	}
	defer fp.Close()

	if buf, err = ioutil.ReadAll(fp); err != nil {
		log.Fatal(fmt.Errorf("Could not read config file: %q", err))
	}

	// Parsing YAML.
	if err = yaml.Unmarshal(buf, &cfg); err != nil {
		log.Fatal(fmt.Errorf("Could not parse config file: %q", err))
	}

	var checksum []byte

	if checksum, err = update.ChecksumForFile(*flagSource); err != nil {
		log.Fatal(fmt.Errorf("Could not create checksum for file: %q", err))
	}

	checksumHex := hex.EncodeToString(checksum)

	log.Printf("%s %s\n", checksumHex, *flagSource)

	// Loading private key
	var pb []byte
	var fpk *os.File

	if fpk, err = os.Open(cfg.PrivateKey); err != nil {
		log.Fatal(fmt.Errorf("Could not open private key: %q", err))
	}
	defer fpk.Close()

	if pb, err = ioutil.ReadAll(fpk); err != nil {
		log.Fatal(fmt.Errorf("Could not read private key: %q", err))
	}

	// Decoding PEM key.
	pemBlock, _ := pem.Decode(pb)

	var privateKey *rsa.PrivateKey
	if privateKey, err = x509.ParsePKCS1PrivateKey(pemBlock.Bytes); err != nil {
		log.Fatal(fmt.Errorf("Could not parse private key: %q", err))
	}

	// Checking message signature.
	var signature []byte
	if signature, err = rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, checksum); err != nil {
		log.Fatal(fmt.Errorf("Could not create signature for file: %q", err))
	}

	signatureHex := hex.EncodeToString(signature)

	// Creating client
	var res *client.AssetResponse

	cli := client.NewClient(cfg)

	// Uploading asset.
	log.Printf("Uploading asset...")

	if res, err = cli.UploadAsset(*flagSource); err != nil {
		log.Fatal(fmt.Errorf("Could not upload release: %q", err))
	}

	// Preparing release message.
	announce := &client.Announcement{
		Version: strconv.Itoa(*flagVersion),
		Tags: map[string]string{
			"channel": *flagChannel,
		},
		Active: true,
		Assets: []client.AnnouncementAsset{
			client.AnnouncementAsset{
				URL:       res.URL,
				Checksum:  checksumHex,
				Signature: signatureHex,
				Tags: map[string]string{
					"arch": *flagArch,
					"os":   *flagOS,
				},
			},
		},
	}

	// Announcing release.
	var annres *client.Announcement

	log.Printf("Announcing release...")

	if annres, err = cli.AnnounceRelease(announce); err != nil {
		log.Fatal(fmt.Errorf("Failed to actually announce release: %q", err))
	}

	if !annres.Active {
		log.Fatal(fmt.Errorf("Failed to enable release."))
	}

	log.Printf("Release uploaded successfully!")
}
