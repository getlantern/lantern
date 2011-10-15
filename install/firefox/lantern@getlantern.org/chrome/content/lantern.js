var Lantern = {
	// Install a timeout handler to install the interval routine

    prefs: null,

    lanternRunning: function() {
        var home = DirIO.get('Home');
        dump("Home: "+DirIO.path(home)+"\n");
        //var fileIn = FileIO.open('/test.txt');
        var fullPath = DirIO.path(home)+'/.lantern/lanternRunning';
        dump("Full path: "+fullPath+"\n");
        var normalized = fullPath.substring(7);
        dump("Normalized: "+normalized+"\n");
        var fileIn = FileIO.open(normalized);
        dump("Opened file..."+fileIn+"\n");
        return fileIn.exists();
    },

    checkForLantern: function() {
        dump("Checking for Lantern\n");
        if (!this.lanternRunning()) {
            dump("Lantern not running...\n");            
            this.prefs.setIntPref("type", 1);
        } else {
            dump("Lantern running!!\n");            
            // Set FireFox to use the system proxy settings.
            this.prefs.setIntPref("type", 5);
        }
    },

    startup: function() {
        dump("Starting Lantern extension...\n");

        this.prefs = Components.classes["@mozilla.org/preferences-service;1"]
            .getService(Components.interfaces.nsIPrefService)
            .getBranch("network.proxy.");

        
        dump("Checking for Lantern...\n");                      
        this.checkForLantern();
        dump("Setting interval...\n");              
        window.setInterval(function() {Lantern.checkForLantern();}, 2000);
        dump("Set interval\n");              
    },
}

window.addEventListener("load", function(e) { Lantern.startup(); }, false);
