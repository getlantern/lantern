package server

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/getlantern/go-update"
)

const (
	privateKeyEnv = `PRIVATE_KEY`
)

var (
	privateKeyFile string
)

func init() {
	privateKeyFile = os.Getenv(privateKeyEnv)
}

func SetPrivateKey(s string) {
	privateKeyFile = s
}

func checksumForFile(file string) (checksumHex string, err error) {
	var checksum []byte
	if checksum, err = update.ChecksumForFile(file); err != nil {
		return "", err
	}
	checksumHex = hex.EncodeToString(checksum)
	return checksumHex, nil
}

func signatureForFile(file string) (signatureHex string, err error) {

	if privateKeyFile == "" {
		log.Fatalf("Missing %s environment variable.", privateKeyEnv)
	}

	var checksum string

	if checksum, err = checksumForFile(file); err != nil {
		return "", err
	}

	var checksumHex []byte
	if checksumHex, err = hex.DecodeString(checksum); err != nil {
		return "", err
	}

	// Loading private key
	var pb []byte
	var fpk *os.File

	if fpk, err = os.Open(privateKeyFile); err != nil {
		return "", fmt.Errorf("Could not open private key: %q", err)
	}
	defer fpk.Close()

	if pb, err = ioutil.ReadAll(fpk); err != nil {
		return "", fmt.Errorf("Could not read private key: %q", err)
	}

	// Decoding PEM key.
	pemBlock, _ := pem.Decode(pb)

	var privateKey *rsa.PrivateKey
	if privateKey, err = x509.ParsePKCS1PrivateKey(pemBlock.Bytes); err != nil {
		return "", fmt.Errorf("Could not parse private key: %q", err)
	}

	// Checking message signature.
	var signature []byte
	if signature, err = rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, checksumHex); err != nil {
		return "", fmt.Errorf("Could not create signature for file %s: %q", file, err)
	}

	signatureHex = hex.EncodeToString(signature)

	return signatureHex, nil
}
