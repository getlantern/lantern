# terminal-notifier

terminal-notifier is a command-line tool to send Mac OS X User Notifications,
which are available in Mac OS X 10.8 and higher.


## Caveats

* Under OS X 10.8, the Notification Center _always_ uses the application’s own
  icon, there’s currently no way to specify a custom icon for a notification. The only
  way to use this tool with your own icon is to use the `-sender` option or include a
  build of terminal-notifier with your icon and **a different bundle identifier**
  instead. (If you do not change the bundle identifier, launch services will use
  a cached version of the icon.)
  <br/>Consequently the `-appIcon` & `-contentImage` options aren't doing anything
  under 10.8.
  <br/>However, you _can_ use unicode symbols and emojis. See the examples.

* It is currently packaged as an application bundle, because `NSUserNotification`
  does not work from a ‘Foundation tool’. [radar://11956694](radar://11956694)

* If you intend to package terminal-notifier with your app to distribute it on the
  MAS, please use 1.5.2 since 1.6.0+ uses a private method override which is not
  allowed in the AppStore guidelines.


## Download

Prebuilt binaries are available from the
[releases section](https://github.com/alloy/terminal-notifier/releases).

Or if you want to use this from
[Ruby](https://github.com/alloy/terminal-notifier/tree/master/Ruby), you can
install it through RubyGems:

```
$ [sudo] gem install terminal-notifier
```

You can also install it via [Homebrew](https://github.com/mxcl/homebrew):
```
$ brew install terminal-notifier
```

## Usage

```
$ ./terminal-notifier.app/Contents/MacOS/terminal-notifier -[message|group|list] [VALUE|ID|ID] [options]
```

In order to use terminal-notifier, you have to call the binary _inside_ the
application bundle.

The Ruby gem, which wraps this tool, _does_ have a bin wrapper. If installed
you can simply do:

```
$ terminal-notifier -[message|group|list] [VALUE|ID|ID] [options]
```

This will obviously be a bit slower than using the tool without the wrapper.

Some examples are:

```
$ echo 'Piped Message Data!' | terminal-notifier -sound default
$ terminal-notifier -title '💰' -message 'Check your Apple stock!' -open 'http://finance.yahoo.com/q?s=AAPL'
$ terminal-notifier -group 'address-book-sync' -title 'Address Book Sync' -subtitle 'Finished' -message 'Imported 42 contacts.' -activate 'com.apple.AddressBook'
```


#### Options

At a minimum, you have to specify either the `-message` , the `-remove`
or the `-list` option.

-------------------------------------------------------------------------------

`-message VALUE`  **[required]**

The message body of the notification.

Note that if this option is omitted and data is piped to the application, that
data will be used instead.

-------------------------------------------------------------------------------

`-title VALUE`

The title of the notification. This defaults to ‘Terminal’.

-------------------------------------------------------------------------------

`-subtitle VALUE`

The subtitle of the notification.

-------------------------------------------------------------------------------

`-sound NAME`

The name of a sound to play when the notification appears. The names are listed
in Sound Preferences. Use 'default' for the default notification sound.

-------------------------------------------------------------------------------

`-group ID`

Specifies the ‘group’ a notification belongs to. For any ‘group’ only _one_
notification will ever be shown, replacing previously posted notifications.

A notification can be explicitely removed with the `-remove` option, describe
below.

Examples are:

* The sender’s name to scope the notifications by tool.
* The sender’s process ID to scope the notifications by a unique process.
* The current working directory to scope notifications by project.

-------------------------------------------------------------------------------

`-remove ID`  **[required]**

Removes a notification that was previously sent with the specified ‘group’ ID,
if one exists. If used with the special group "ALL", all message are removed.

-------------------------------------------------------------------------------

`-list ID` **[required]**

Lists details about the specified ‘group’ ID. If used with the special group
"ALL", details about all currently active  messages are displayed.

The output of this command is tab-separated, which makes it easy to parse.

-------------------------------------------------------------------------------

`-activate ID`

Specifies which application should be activated when the user clicks the
notification.

You can find the bundle identifier of an application in its `Info.plist` file
_inside_ the application bundle.

Examples are:

* `com.apple.Terminal` to activate Terminal.app
* `com.apple.Safari` to activate Safari.app

-------------------------------------------------------------------------------

`-sender ID`

Specifying this will make it appear as if the notification was send by that
application instead, including using its icon.

Using this option fakes the sender application, so that the notification system
will launch that application when the notification is clicked. Because of this
it is important to note that you cannot combine this with options like
`-execute` and `-activate` which depend on the sender of the notification to be
‘terminal-notifier’ to perform its work.

For information on the `ID` see the `-activate` option.

-------------------------------------------------------------------------------

`-appIcon PATH` **[10.9+ only]**

Specifies The PATH of an image to display instead of the application icon.

**WARNING: This option is subject to change since it relies on a private method.**

-------------------------------------------------------------------------------

`-contentImage PATH` **[10.9+ only]**

Specifies The PATH of an image to display attached inside the notification.

**WARNING: This option is subject to change since it relies on a private method.**

-------------------------------------------------------------------------------

`-open URL`

Specifies a resource to be opened when the user clicks the notification. This
can be a web or file URL, or any custom URL scheme.

-------------------------------------------------------------------------------

`-execute COMMAND`

Specifies a shell command to run when the user clicks the notification.


## License

All the works are available under the MIT license. **Except** for
‘Terminal.icns’, which is a copy of Apple’s Terminal.app icon and as such is
copyright of Apple.

Copyright (C) 2012-2015 Eloy Durán <eloy.de.enige@gmail.com>, Julien Blanchard
<julien@sideburns.eu>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
