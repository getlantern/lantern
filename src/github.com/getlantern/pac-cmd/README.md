# pac-cmd

A command line tool to change proxy auto-config settings of operation system.

Binaries included in repo. Simply `make` to build it again. You can also use the supplied xcode project to build on OSX, which is useful because it correctly sets things like the deployment target (10.6) and the code signing to use. To run it, simply type `xcodebuild`.

Note - you will need to run make separately on each platform.

# Usage

```sh
pac on  <pac-url>
pac off [old-pac-url]
```

`pac off` with `old-pac-url` will turn off pac setting only if the existing pac url is equal to `old-pac-url`.

#Notes

*  **Mac**
  
Setting pac is an privileged action on Mac OS. `sudo` or elevate it as below.

There's an additional option to chown itself to root:wheel and add setuid bit.

```sh
pac setuid
```

*  **Windows**

Install [MinGW-W64](http://sourceforge.net/projects/mingw-w64) to build pac, as it has up to date SDK headers we require.

*  **Linux**

`sudo apt-get install libgtk2.0-dev`
