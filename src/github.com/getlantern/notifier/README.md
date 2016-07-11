# notifier
A library for sending native desktop notifications from Go designed distribution particularly within other apps that care about install size. This uses platform-specific helper libraries as follows:

* OSX: [Terminal Notifier](https://github.com/julienXX/terminal-notifier)
* Windows: [notifu](https://www.paralint.com/projects/notifu/)

Those libraries are embedded directly in Go in this library using [go-bindata](https://github.com/jteeuwen/go-bindata), so there are no external dependencies or expectations for installations on the user's system. These libraries were also chosen for their small size, particularly in the case of notifu, which is far smaller than things like Growl or Snarl.


To generate updated embedded binaries, you first need go-bindata:

```
go get -u github.com/jteeuwen/go-bindata/...
```

Then you can run, for example:

```
cd platform/terminal-notifier-1.6.3
go-bindata -pkg osx --nomemcopy -nocompress terminal-notifier.app/...
mv bindata.go ../../osx
```

```
cd platform/notifu-1.6
go-bindata -pkg win --nomemcopy -nocompress notifu.exe
mv bindata.go ../../win
```

This is currently a work in progress and only runs on OSX and Windows and embeds
all binaries for all platforms instead of dynamically only including the
required platform at build time, for example.

The platform directory is only here to serve as a reference for the native binaries
being used.

For documentation purposes, here are the raw options for terminal-notifier:

```
$ ./terminal-notifier.app/Contents/MacOS/terminal-notifier
terminal-notifier (1.6.3) is a command-line tool to send OS X User Notifications.

Usage: terminal-notifier -[message|list|remove] [VALUE|ID|ID] [options]

   Either of these is required (unless message data is piped to the tool):

       -help              Display this help banner.
       -message VALUE     The notification message.
       -remove ID         Removes a notification with the specified ‘group’ ID.
       -list ID           If the specified ‘group’ ID exists show when it was delivered,
                          or use ‘ALL’ as ID to see all notifications.
                          The output is a tab-separated list.

   Optional:

       -title VALUE       The notification title. Defaults to ‘Terminal’.
       -subtitle VALUE    The notification subtitle.
       -sound NAME        The name of a sound to play when the notification appears. The names are listed
                          in Sound Preferences. Use 'default' for the default notification sound.
       -group ID          A string which identifies the group the notifications belong to.
                          Old notifications with the same ID will be removed.
       -activate ID       The bundle identifier of the application to activate when the user clicks the notification.
       -sender ID         The bundle identifier of the application that should be shown as the sender, including its icon.
       -appIcon URL       The URL of a image to display instead of the application icon (Mavericks+ only)
       -contentImage URL  The URL of a image to display attached to the notification (Mavericks+ only)
       -open URL          The URL of a resource to open when the user clicks the notification.
       -execute COMMAND   A shell command to perform when the user clicks the notification.

When the user activates a notification, the results are logged to the system logs.
Use Console.app to view these logs.

Note that in some circumstances the first character of a message has to be escaped in order to be recognized.
An example of this is when using an open bracket, which has to be escaped like so: ‘\[’.
```

Here are the docs for notifu:

```
Usage: notifu [@argfile] [/?|h|help] [/v|version] [/t <value>] [/d <value>] [/p <value>] 
                  /m <value< [/i <value>] [/e]

@argfile        Read arguments from a file.


/?              Show usage.
/v              Show version.
/t <value>      The type of message to display values are:
                    info      The message is an informational message
                    warn      The message is an warning message
                    error     The message is an error message
/d <value>      The number of milliseconds to display (omit or 0 for infinit)
/p <value>      The title (or prompt) of the ballon
/m <value>      The message text
/i <value>      Specify an icon to use ("parent" uses the icon of the parent process)
/e              Enable ballon tips in the registry (for this user only)
/q              Do not play a sound when the tooltip is displayed
/w              Show the tooltip even if the user is in the quiet period that follows his very first login (Windows 7 and up)
/xp             Use IUserNotification interface event when IUserNotification2 is available
```
