var Lantern = {
	// Install a timeout handler to install the interval routine

    prefs: null,

    startup: function() {
        this.prefs = Components.classes["@mozilla.org/preferences-service;1"]
            .getService(Components.interfaces.nsIPrefService)
            .getBranch("network.proxy.");

        // Set FireFox to use the system proxy settings.
        this.prefs.setIntPref("type", 5);
    },
}

window.addEventListener("load", function(e) { Lantern.startup(); }, false);
