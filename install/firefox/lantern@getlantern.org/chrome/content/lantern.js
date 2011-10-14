var Lantern = {
	// Install a timeout handler to install the interval routine

    prefs: null,

    lanternRunning: function() {
        var fileIn = FileIO.open('/test.txt');
	return fileIn.exists();
    },

    startup: function() {
        dump("Starting Lantern extension...");

        this.prefs = Components.classes["@mozilla.org/preferences-service;1"]
            .getService(Components.interfaces.nsIPrefService)
            .getBranch("network.proxy.");

        if (!this.lanternRunning()) {
            dump("Lantern not running...");            
            this.prefs.setIntPref("type", 1);
        } else {
            dump("Lantern running!!");            
            // Set FireFox to use the system proxy settings.
            this.prefs.setIntPref("type", 5);
        }
    },
}

window.addEventListener("load", function(e) { Lantern.startup(); }, false);
