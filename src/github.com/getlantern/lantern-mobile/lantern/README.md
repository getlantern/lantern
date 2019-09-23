# Lantern on Android

```java
import go.flashlight.Flashlight;
```

The `lantern-android` repository provides documentation and scripts for
building a basic [flashlight][1] shared library that exports special methods
that can be used from Java code, making it possible to run the [flashlight][1]
client on Android devices.

```java
try {
  Flashlight.RunClientProxy("0.0.0.0:9192");
} catch (Exception e) {
  throw new RuntimeException(e);
}
```

## Prerequisites

* An OSX or Linux box
* [docker][2]
* [Android Studio][3]
* [Go 1.4][4]
* [GNUMake][6]
* [Mercurial][7]: You can try installing it with `brew` or `macports`.

### Setting up a development environment

We're going to clone and use the [flashlight-build][5] repository, that
project provides us with everything we need to build Lantern tools and
libraries.

```sh
mkdir -p $GOPATH/src/github.com/getlantern
cd $GOPATH/src/github.com/getlantern
git clone https://github.com/getlantern/flashlight-build.git
```

## Building the Android library

After cloning the repository use `make android` to build the Android library,
this library is going to be built at
`src/github.com/getlantern/lantern-android/app/libs/armeabi-v7a/libgojni.so`:

```
make android-lib
...
BUILD SUCCESSFUL
Total time: 4 seconds
```

The `make` command will create a new
`src/github.com/getlantern/lantern-android/app` subdirectory that will contain
an Android example project. You may import the contents of the `app`
subdirectory into Android Studio to see libflashlight working.

## Testing the example project

Open [Android Studio][3] and in the welcome screen choose "Import Non-Android
Studio project".

![Android Studio](https://cloud.githubusercontent.com/assets/385670/5712830/5f4cda3c-9a7b-11e4-85af-8af9d54e18c7.png)

You'll be prompted with a file dialog, browse to the `app` subdirectory and
select it. Press *OK*.

![App Subdirectory](https://cloud.githubusercontent.com/assets/385670/5769230/5431dec6-9cde-11e4-82ce-d3983471a1f1.png)

On the next dialog you must define a destination for the project, hit *Next*.

![Destination](https://cloud.githubusercontent.com/assets/385670/5712874/ad8265e6-9a7b-11e4-9018-671875dfdb17.png)

After import you may be prompted to restart Android Studio.

Now add a new *main activity* by right-clicking on the top most directory on
the *Project* pane and selecting New->Activity->Blank Activity, the default
values would be OK, click *Finish*.

![Main Activity](https://cloud.githubusercontent.com/assets/385670/5712891/ca3573fe-9a7b-11e4-953d-d43b12fcdb62.png)

Paste the following code on the `org.getlantern/example/MainActivity.java` file
that was just added:

```java
package org.getlantern.example;

import go.Go;
import go.flashlight.Flashlight;
import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import org.getlantern.example.R;


public class MainActivity extends Activity {


    private Button killButton;
    private Button startButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_main);

        // Initializing application context.
        Go.init(getApplicationContext());

        killButton = (Button)findViewById(R.id.stopProxyButton);
        startButton = (Button)findViewById(R.id.startProxyButton);

        // Disabling stop button.
        killButton.setEnabled(false);

        // Enabling proxy button.
        startButton.setEnabled(true);
    }

    public void stopProxyButtonOnClick(View v) {

        Log.v("DEBUG", "Attempt to stop running proxy.");
        try {
            Flashlight.StopClientProxy();
        } catch (Exception e) {
            throw new RuntimeException(e);
        };

        // Disabling stop button.
        killButton.setEnabled(false);

        // Enabling proxy button.
        startButton.setEnabled(true);

    }

    public void startProxyButtonOnClick(View v) {
        Log.v("DEBUG", "Attempt to run client proxy on :9192");

        try {
            Flashlight.RunClientProxy("0.0.0.0:9192");
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        // Enabling stop button.
        killButton.setEnabled(true);

        // Disabling proxy button.
        startButton.setEnabled(false);
    }
}
```

After this new activity is added the *design view* will be active, drag two
buttons from the *Pallete* into the screen.

![Adding two buttons](https://cloud.githubusercontent.com/assets/385670/5769192/d9df19cc-9cdd-11e4-90d0-b37b6d6b3a41.png)

Select the first button and look for the *id* property on the Properties pane,
set it to *startProxyButton* and name the button accordingly. Look for the
*onClick* property and choose the *startProxyButtonOnClick* value from the drop
down.

The second button's *id* must be set to *stopProxyButton* and the *onClick* to
*stopProxyButtonOnClick*.

Finally, hit the *Run app* action under the *Run* menu and deploy it to a real
device or to an ARM-based emulator (armeabi-v7a).

![ARM-based emulator](https://cloud.githubusercontent.com/assets/385670/5985944/2e5016e0-a8b0-11e4-99fe-c9b4d325a5f4.png)

I you're having configuration related problems when attempting to build, make
sure your `AndroidManifest.xml` looks like this:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!--
Copyright 2014 The Go Authors. All rights reserved.
Use of this source code is governed by a BSD-style
license that can be found in the LICENSE file.
-->
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="org.getlantern.example" android:versionCode="1" android:versionName="1.0">

  <application android:label="Flashlight">
    <activity android:name="org.getlantern.example.MainActivity"
      android:label="Flashlight"
      android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
    </activity>
  </application>
  <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

If everything goes OK, you'll have two buttons and you can start `flashlight`
by touching the *startProxyButton*.

![Deploy to a device](https://cloud.githubusercontent.com/assets/385670/5712899/db6ddb34-9a7b-11e4-8841-6b6b12e46c27.png)

As long as the app is open, you'll be able to test the canonical example by
finding the device's IP and sending it a special request:

```sh
curl -x 10.10.100.97:9192 http://www.google.com/humans.txt
# Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.
```

You may not want everyone proxying through your phone! Tune the
`RunClientProxy()` function on the `MainActivity.java` accordingly.

If you chose to run flashlight inside an emulator instead of a real device, you
must connect to it using telnet and set up port redirection to actually test
the proxy.

Identify the port number your emulator is listening to

![screen shot 2015-01-30 at 6 40 52 pm](https://cloud.githubusercontent.com/assets/385670/5985952/6afa23e2-a8b0-11e4-942a-384f483d331a.png)

In this case its listening on the `5554` local port.

Open a telnet session to the emulator and write the instruction `redir add
tcp:9192:9192` to map the emulator's `9192` port to our local `9192` port.

```sh
telnet 127.0.0.1 5554
# Trying 127.0.0.1...
# Connected to localhost.
# Escape character is '^]'.
# Android Console: type 'help' for a list of commands
# OK
redir add tcp:9192:9192
# OK
```

Now you'll be able to connect to the emulator's flashlight proxy through your
local `9192` port:

```sh
curl -x 127.0.0.1:9192 https://www.google.com/humans.txt
# Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.
```

[1]: https://github.com/getlantern/flashlight
[2]: https://www.docker.com/
[3]: http://developer.android.com/tools/studio/index.html
[4]: http://golang.org/
[5]: https://github.com/getlantern/flashlight-build
[6]: http://www.gnu.org/software/make/
[7]: http://mercurial.selenic.com/wiki/Download
