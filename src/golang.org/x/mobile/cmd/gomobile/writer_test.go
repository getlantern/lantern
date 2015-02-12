// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"crypto/x509"
	"encoding/pem"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"testing"
)

func TestWriter(t *testing.T) {
	block, _ := pem.Decode([]byte(debugCert))
	if block == nil {
		t.Fatal("no cert")
	}
	privKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		t.Fatal(err)
	}

	f, err := ioutil.TempFile("", "testapk-")
	if err != nil {
		t.Fatal(err)
	}
	f.Close()
	apkPath := f.Name() + ".apk"

	f, err = os.Create(apkPath)
	if err != nil {
		t.Fatal(err)
	}

	apkw := NewWriter(f, privKey)

	w, err := apkw.Create("AndroidManifest.xml")
	if err != nil {
		t.Fatalf("could not create AndroidManifest.xml: %v", err)
	}
	if _, err := w.Write([]byte(androidManifest)); err != nil {
		t.Errorf("could not write AndroidManifest.xml: %v", err)
	}

	w, err = apkw.Create("assets/hello_world.txt")
	if err != nil {
		t.Fatalf("could not create assets/hello_world.txt: %v", err)
	}
	if _, err := w.Write([]byte("Hello, 世界")); err != nil {
		t.Errorf("could not write assets/hello_world.txt: %v", err)
	}

	if err := apkw.Close(); err != nil {
		t.Fatal(err)
	}

	if exec.Command("which", "aapt").Run() != nil {
		t.Skip("command aapt not found, skipping")
	}

	out, err := exec.Command("aapt", "list", "-a", apkPath).CombinedOutput()
	aaptGot := string(out)
	if err != nil {
		t.Logf("aapt:\n%s", aaptGot)
		t.Fatalf("aapt failed: %v", err)
	}

	if aaptGot != aaptWant {
		t.Errorf("unexpected output from aapt")
		d, err := diff(aaptWant, aaptGot)
		if err != nil {
			t.Errorf("diff failed: %v", err)
		} else {
			t.Logf("%s", d)
		}
	}
}

const aaptWant = `AndroidManifest.xml
assets/hello_world.txt
META-INF/MANIFEST.MF
META-INF/CERT.SF
META-INF/CERT.RSA

Resource table:
Package Groups (0)

Android manifest:
N: android=http://schemas.android.com/apk/res/android
  E: manifest (line=2)
    A: package="org.golang.fakeapp" (Raw: "org.golang.fakeapp")
    A: android:versionCode(0x0101021b)=(type 0x10)0x1
    A: android:versionName(0x0101021c)="1.0" (Raw: "1.0")
    E: uses-sdk (line=8)
      A: android:minSdkVersion(0x0101020c)=(type 0x10)0x9
    E: application (line=9)
      A: android:label(0x01010001)="FakeApp" (Raw: "FakeApp")
      A: android:hasCode(0x0101000c)=(type 0x12)0x0
      A: android:debuggable(0x0101000f)=(type 0x12)0xffffffff
      E: activity (line=10)
        A: android:name(0x01010003)="android.app.NativeActivity" (Raw: "android.app.NativeActivity")
        A: android:label(0x01010001)="FakeApp" (Raw: "FakeApp")
        A: android:configChanges(0x0101001f)=(type 0x11)0xa0
        E: intent-filter (line=14)
          E: action (line=15)
            A: android:name(0x01010003)="android.intent.action.MAIN" (Raw: "android.intent.action.MAIN")
          E: category (line=16)
            A: android:name(0x01010003)="android.intent.category.LAUNCHER" (Raw: "android.intent.category.LAUNCHER")
`

const androidManifest = `
<manifest
	xmlns:android="http://schemas.android.com/apk/res/android"
	package="org.golang.fakeapp"
	android:versionCode="1"
	android:versionName="1.0">

	<uses-sdk android:minSdkVersion="9" />
	<application android:label="FakeApp" android:hasCode="false" android:debuggable="true">
		<activity android:name="android.app.NativeActivity"
			android:label="FakeApp"
			android:configChanges="orientation|keyboardHidden">

			<intent-filter>
				<action android:name="android.intent.action.MAIN" />
				<category android:name="android.intent.category.LAUNCHER" />
			</intent-filter>
		</activity>
	</application>
</manifest>
`

// A random uninteresting private key.
const debugCert = `
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAy6ItnWZJ8DpX9R5FdWbS9Kr1U8Z7mKgqNByGU7No99JUnmyu
NQ6Uy6Nj0Gz3o3c0BXESECblOC13WdzjsH1Pi7/L9QV8jXOXX8cvkG5SJAyj6hcO
LOapjDiN89NXjXtyv206JWYvRtpexyVrmHJgRAw3fiFI+m4g4Qop1CxcIF/EgYh7
rYrqh4wbCM1OGaCleQWaOCXxZGm+J5YNKQcWpjZRrDrb35IZmlT0bK46CXUKvCqK
x7YXHgfhC8ZsXCtsScKJVHs7gEsNxz7A0XoibFw6DoxtjKzUCktnT0w3wxdY7OTj
9AR8mobFlM9W3yirX8TtwekWhDNTYEu8dwwykwIDAQABAoIBAA2hjpIhvcNR9H9Z
BmdEecydAQ0ZlT5zy1dvrWI++UDVmIp+Ve8BSd6T0mOqV61elmHi3sWsBN4M1Rdz
3N38lW2SajG9q0fAvBpSOBHgAKmfGv3Ziz5gNmtHgeEXfZ3f7J95zVGhlHqWtY95
JsmuplkHxFMyITN6WcMWrhQg4A3enKLhJLlaGLJf9PeBrvVxHR1/txrfENd2iJBH
FmxVGILL09fIIktJvoScbzVOneeWXj5vJGzWVhB17DHBbANGvVPdD5f+k/s5aooh
hWAy/yLKocr294C4J+gkO5h2zjjjSGcmVHfrhlXQoEPX+iW1TGoF8BMtl4Llc+jw
lKWKfpECgYEA9C428Z6CvAn+KJ2yhbAtuRo41kkOVoiQPtlPeRYs91Pq4+NBlfKO
2nWLkyavVrLx4YQeCeaEU2Xoieo9msfLZGTVxgRlztylOUR+zz2FzDBYGicuUD3s
EqC0Wv7tiX6dumpWyOcVVLmR9aKlOUzA9xemzIsWUwL3PpyONhKSq7kCgYEA1X2F
f2jKjoOVzglhtuX4/SP9GxS4gRf9rOQ1Q8DzZhyH2LZ6Dnb1uEQvGhiqJTU8CXxb
7odI0fgyNXq425Nlxc1Tu0G38TtJhwrx7HWHuFcbI/QpRtDYLWil8Zr7Q3BT9rdh
moo4m937hLMvqOG9pyIbyjOEPK2WBCtKW5yabqsCgYEAu9DkUBr1Qf+Jr+IEU9I8
iRkDSMeusJ6gHMd32pJVCfRRQvIlG1oTyTMKpafmzBAd/rFpjYHynFdRcutqcShm
aJUq3QG68U9EAvWNeIhA5tr0mUEz3WKTt4xGzYsyWES8u4tZr3QXMzD9dOuinJ1N
+4EEumXtSPKKDG3M8Qh+KnkCgYBUEVSTYmF5EynXc2xOCGsuy5AsrNEmzJqxDUBI
SN/P0uZPmTOhJIkIIZlmrlW5xye4GIde+1jajeC/nG7U0EsgRAV31J4pWQ5QJigz
0+g419wxIUFryGuIHhBSfpP472+w1G+T2mAGSLh1fdYDq7jx6oWE7xpghn5vb9id
EKLjdwKBgBtz9mzbzutIfAW0Y8F23T60nKvQ0gibE92rnUbjPnw8HjL3AZLU05N+
cSL5bhq0N5XHK77sscxW9vXjG0LJMXmFZPp9F6aV6ejkMIXyJ/Yz/EqeaJFwilTq
Mc6xR47qkdzu0dQ1aPm4XD7AWDtIvPo/GG2DKOucLBbQc2cOWtKS
-----END RSA PRIVATE KEY-----
`

func diff(s1, s2 string) (data []byte, err error) {
	f1, err := ioutil.TempFile("", "apk-writer-diff")
	if err != nil {
		return
	}
	defer os.Remove(f1.Name())
	defer f1.Close()

	f2, err := ioutil.TempFile("", "apk-writer-diff")
	if err != nil {
		return
	}
	defer os.Remove(f2.Name())
	defer f2.Close()

	io.WriteString(f1, s1)
	io.WriteString(f2, s2)

	data, err = exec.Command("diff", "-u", f1.Name(), f2.Name()).CombinedOutput()
	if len(data) > 0 {
		// diff exits with a non-zero status when the files don't match.
		// Ignore that failure as long as we get output.
		err = nil
	}
	return
}
