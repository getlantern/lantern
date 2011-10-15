var Lantern = {
	// Install a timeout handler to install the interval routine

    prefs: null,

    originalProxyType: 5,

    setProxy: false,

    lanternRunning: function() {
        var home = DirIO.get('Home');
        //dump("Home: "+DirIO.path(home)+"\n");
        var fullPath = DirIO.path(home)+'/.lantern/lanternRunning';
        //dump("Full path: "+fullPath+"\n");
        var normalized = fullPath.substring(7);
        //dump("Normalized: "+normalized+"\n");
        var fileIn = FileIO.open(normalized);
        //dump("Opened file..."+fileIn+"\n");
        return fileIn.exists();
    },

    checkForLantern: function() {
        dump("Checking for Lantern\n");
        if (!this.lanternRunning()) {
            dump("Lantern not running...\n");
            if (this.setProxy) { 
                this.setProxy = false;
		dump("Setting back to type: "+this.originalProxyType+"\n");           
                this.prefs.setIntPref("type", this.originalProxyType);
            }
        } else {
            dump("Lantern running!!\n");            
            // Set FireFox to use the system proxy settings.
            var pref = this.prefs.getIntPref("type");
            dump("Pref: "+pref+"\n");
            if (pref != 5) {
                this.originalProxyType = pref;
                this.prefs.setIntPref("type", 5);
                this.setProxy = true;
            }
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
