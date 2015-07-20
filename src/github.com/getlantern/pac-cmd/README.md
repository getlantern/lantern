# pac-cmd

A command line tool to change proxy auto-config settings of operation system.

Binaries included in repo. Simply `make` to build it again.

Note - you will need to run make separately on each platform.

# Usage

```sh
pac [on  <pac url> | off]
```

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