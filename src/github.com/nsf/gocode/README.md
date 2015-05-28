## An autocompletion daemon for the Go programming language

Gocode is a helper tool which is intended to be integrated with your source code editor, like vim and emacs. It provides several advanced capabilities, which currently includes:

 - Context-sensitive autocompletion

It is called *daemon*, because it uses client/server architecture for caching purposes. In particular, it makes autocompletions very fast. Typical autocompletion time with warm cache is 30ms, which is barely noticeable.

Also watch the [demo screencast](http://nosmileface.ru/images/gocode-demo.swf).

![Gocode in vim](http://nosmileface.ru/images/gocode-screenshot.png)

![Gocode in emacs](http://nosmileface.ru/images/emacs-gocode.png)

### Setup

 1. You should have a correctly installed Go compiler environment and your personal workspace ($GOPATH). If you have no idea what **$GOPATH** is, take a look [here](http://golang.org/doc/code.html). Please make sure that your **$GOPATH/bin** is available in your **$PATH**. This is important, because most editors assume that **gocode** binary is available in one of the directories, specified by your **$PATH** environment variable. Otherwise manually copy the **gocode** binary from **$GOPATH/bin** to a location which is part of your **$PATH** after getting it in step 2.

    Do these steps only if you understand why you need to do them:

    `export GOPATH=$HOME/goprojects`

    `export PATH=$PATH:$GOPATH/bin`

 2. Then you need to get the appropriate version of the gocode, for 6g/8g/5g compiler you can do this:

    `go get -u github.com/nsf/gocode` (-u flag for "update")

    Windows users should consider doing this instead:

    `go get -u -ldflags -H=windowsgui github.com/nsf/gocode`

    That way on the Windows OS gocode will be built as a GUI application and doing so solves hanging window issues with some of the editors.

 3. Next steps are editor specific. See below.

### Vim setup

#### Manual installation

In order to install vim scripts, you need to fulfill the following steps:

 1. Install official Go vim scripts from **$GOROOT/misc/vim**. If you did that already, proceed to the step 2.

 2. Install gocode vim scripts. Usually it's enough to do the following:

    2.1. `vim/update.sh`

    **update.sh** script does the following:

		#!/bin/sh
		mkdir -p "$HOME/.vim/autoload"
		mkdir -p "$HOME/.vim/ftplugin/go"
		cp "${0%/*}/autoload/gocomplete.vim" "$HOME/.vim/autoload"
		cp "${0%/*}/ftplugin/go/gocomplete.vim" "$HOME/.vim/ftplugin/go"

    2.2. Alternatively, you can create symlinks using symlink.sh script in order to avoid running update.sh after every gocode update.

    **symlink.sh** script does the following:

		#!/bin/sh
		cd "${0%/*}"
		ROOTDIR=`pwd`
		mkdir -p "$HOME/.vim/autoload"
		mkdir -p "$HOME/.vim/ftplugin/go"
		ln -s "$ROOTDIR/autoload/gocomplete.vim" "$HOME/.vim/autoload/"
		ln -s "$ROOTDIR/ftplugin/go/gocomplete.vim" "$HOME/.vim/ftplugin/go/"

 3. Make sure vim has filetype plugin enabled. Simply add that to your **.vimrc**:

    `filetype plugin on`

 4. Autocompletion should work now. Use `<C-x><C-o>` for autocompletion (omnifunc autocompletion).

#### Using Vundle

Add the following line to your **.vimrc**:

`Plugin 'nsf/gocode', {'rtp': 'vim/'}`

And then update your packages by running `:PluginInstall`.

#### Other

Alternatively take a look at the vundle/pathogen friendly repo: https://github.com/Blackrush/vim-gocode.

### Emacs setup

In order to install emacs script, you need to fulfill the following steps:

 1. Install [auto-complete-mode](http://www.emacswiki.org/emacs/AutoComplete)

 2. Copy **emacs/go-autocomplete.el** file from the gocode source distribution to a directory which is in your 'load-path' in emacs.

 3. Add these lines to your **.emacs**:

 		(require 'go-autocomplete)
		(require 'auto-complete-config)
		(ac-config-default)

Also, there is an alternative plugin for emacs using company-mode. See `emacs-company/README` for installation instructions.

If you're a MacOSX user, you may find that script useful: https://github.com/purcell/exec-path-from-shell. It helps you with setting up the right environment variables as Go and gocode require it. By default it pulls the PATH, but don't forget to add the GOPATH as well, e.g.:

```
(when (memq window-system '(mac ns))
  (exec-path-from-shell-initialize)
  (exec-path-from-shell-copy-env "GOPATH"))
```

### Options

You can change all available options using `gocode set` command. The config file uses json format and is usually stored somewhere in **~/.config/gocode** directory. On windows it's stored in the appropriate AppData folder. It's suggested to avoid modifying config file manually, do that using the `gocode set` command.

`gocode set` lists all options and their values.

`gocode set <option>` shows the value of that *option*.

`gocode set <option> <value>` sets the new *value* for that *option*.

 - *propose-builtins*

   A boolean option. If **true**, gocode will add built-in types, functions and constants to an autocompletion proposals. Default: **false**.

 - *lib-path*

   A string option. Allows you to add search paths for packages. By default, gocode only searches **$GOPATH/pkg/$GOOS_$GOARCH** and **$GOROOT/pkg/$GOOS_$GOARCH** in terms of previously existed environment variables. Also you can specify multiple paths using ':' (colon) as a separator (on Windows use semicolon ';'). The paths specified by *lib-path* are prepended to the default ones.

 - *autobuild*

   A boolean option. If **true**, gocode will try to automatically build out-of-date packages when their source files are modified, in order to obtain the freshest autocomplete results for them. This feature is experimental. Default: **false**.

 - *force-debug-output*

   A string option. If is not empty, gocode will forcefully redirect the logging into that file. Also forces enabling of the debug mode on the server side. Default: "" (empty).

### Debugging

If something went wrong, the first thing you may want to do is manually start the gocode daemon with a debug mode enabled and in a separate terminal window. It will show you all the stack traces, panics if any and additional info about autocompletion requests. Shutdown the daemon if it was already started and run a new one explicitly with a debug mode enabled:

`gocode close`

`gocode -s -debug`

Please, report bugs, feature suggestions and other rants to the [github issue tracker](http://github.com/nsf/gocode/issues) of this project.

### Developing

There is [Guide for IDE/editor plugin developers](docs/IDE_integration.md).

If you have troubles, please, contact me and I will try to do my best answering your questions. You can contact me via <a href="mailto:no.smile.face@gmail.com">email</a>. Or for short question find me on IRC: #go-nuts @ freenode.

### Misc

 - It's a good idea to use the latest git version always. I'm trying to keep it in a working state.
