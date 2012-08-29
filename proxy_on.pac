var proxyDomains = new Array();
var i=0;

proxyDomains[i++] = "30mail.net";
proxyDomains[i++] = "881903.com";
proxyDomains[i++] = "aboluowang.com";
proxyDomains[i++] = "advar-news.biz";
proxyDomains[i++] = "am730.com.hk";
proxyDomains[i++] = "appledaily.com.tw";
proxyDomains[i++] = "avaaz.org";
proxyDomains[i++] = "balatarin.com";
proxyDomains[i++] = "bbc.co.uk";
proxyDomains[i++] = "bia2.com";
proxyDomains[i++] = "bittorrent.com";
proxyDomains[i++] = "bloglines.com";
proxyDomains[i++] = "blogspot.com";
proxyDomains[i++] = "bloomberg.com";
proxyDomains[i++] = "box.com";
proxyDomains[i++] = "box.net";
proxyDomains[i++] = "boxun.com";
proxyDomains[i++] = "bullogger.com";
proxyDomains[i++] = "canadameet.me";
proxyDomains[i++] = "canyu.org";
proxyDomains[i++] = "change.org";
proxyDomains[i++] = "chinadigitaltimes.net";
proxyDomains[i++] = "chinainperspective.com";
proxyDomains[i++] = "chinasmile.net";
proxyDomains[i++] = "dailymotion.com";
proxyDomains[i++] = "discuss.com.hk";
proxyDomains[i++] = "docstoc.com";
proxyDomains[i++] = "dolc.de";
proxyDomains[i++] = "dropbox.com";
proxyDomains[i++] = "dw.de";
proxyDomains[i++] = "eff.org";
proxyDomains[i++] = "enghelabe-eslami.com";
proxyDomains[i++] = "epochtimes.com";
proxyDomains[i++] = "etaiwannews.com";
proxyDomains[i++] = "exceptional.io";
proxyDomains[i++] = "facebook.com";
proxyDomains[i++] = "fc2.com";
proxyDomains[i++] = "flickr.com";
proxyDomains[i++] = "freedomhouse.org";
proxyDomains[i++] = "friendfeed.com";
proxyDomains[i++] = "getlantern.org";
proxyDomains[i++] = "globalvoicesonline.org";
proxyDomains[i++] = "google.com";
proxyDomains[i++] = "gooya.com";
proxyDomains[i++] = "hk.nextmedia.com";
proxyDomains[i++] = "hrichina.org";
proxyDomains[i++] = "hrw.org";
proxyDomains[i++] = "idv.tw";
proxyDomains[i++] = "ifconfig.me";
proxyDomains[i++] = "igfw.net";
proxyDomains[i++] = "inmediahk.net";
proxyDomains[i++] = "irangreenvoice.com";
proxyDomains[i++] = "iranian.com";
proxyDomains[i++] = "libertytimes.com.tw";
proxyDomains[i++] = "linkedin.com";
proxyDomains[i++] = "littleshoot.org";
proxyDomains[i++] = "livejournal.com";
proxyDomains[i++] = "mardomak.org";
proxyDomains[i++] = "mingpao.com";
proxyDomains[i++] = "molihua.org";
proxyDomains[i++] = "myspace.com";
proxyDomains[i++] = "newcenturynews.com";
proxyDomains[i++] = "nextmedia.com";
proxyDomains[i++] = "ntdtv.com";
proxyDomains[i++] = "on.cc";
proxyDomains[i++] = "orkut.com";
proxyDomains[i++] = "oursteps.com.au";
proxyDomains[i++] = "paypal.com";
proxyDomains[i++] = "pchome.com.tw";
proxyDomains[i++] = "pixnet.net";
proxyDomains[i++] = "plurk.com";
proxyDomains[i++] = "posterous.com";
proxyDomains[i++] = "qoos.com";
proxyDomains[i++] = "radiofarda.com";
proxyDomains[i++] = "radiozamaneh.com";
proxyDomains[i++] = "reddit.com";
proxyDomains[i++] = "rfa.org";
proxyDomains[i++] = "rfi.fr";
proxyDomains[i++] = "roodo.com";
proxyDomains[i++] = "Roozonline.com";
proxyDomains[i++] = "rsf.org";
proxyDomains[i++] = "rthk.hk";
proxyDomains[i++] = "scribd.com";
proxyDomains[i++] = "sgchinese.net";
proxyDomains[i++] = "singtao.com";
proxyDomains[i++] = "student.tw";
proxyDomains[i++] = "stumbleupon.com";
proxyDomains[i++] = "taiwandaily.net";
proxyDomains[i++] = "torproject.org";
proxyDomains[i++] = "tumblr.com";
proxyDomains[i++] = "twbbs.tw";
proxyDomains[i++] = "twitter.com";
proxyDomains[i++] = "uwants.com";
proxyDomains[i++] = "vimeo.com";
proxyDomains[i++] = "voanews.com";
proxyDomains[i++] = "whatismyip.com";
proxyDomains[i++] = "wikileaks.org";
proxyDomains[i++] = "wordpress.com";
proxyDomains[i++] = "wordpress.org";
proxyDomains[i++] = "wretch.cc";
proxyDomains[i++] = "youtube.com";
proxyDomains[i++] = "yzzk.com";

for(i in proxyDomains) {
    proxyDomains[i] = proxyDomains[i].split(/\./).join("\\.");
}

var proxyDomainsRegx = new RegExp("(" + proxyDomains.join("|") + ")$", "i");

function FindProxyForURL(url, host) {
    if( host == "localhost" ||
        host == "127.0.0.1") {
        return "DIRECT";
    }
    
    if (proxyDomainsRegx.exec(host)) {
        return "PROXY 127.0.0.1:8787; DIRECT";
    }
    
    return "DIRECT";
}
