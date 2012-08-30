package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.concurrent.TimeUnit;

import org.junit.Test;
import org.openqa.selenium.Proxy;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.remote.CapabilityType;
import org.openqa.selenium.remote.DesiredCapabilities;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * End-to-end proxying test to make sure we're able to proxy access to 
 * different sites.
 */
public class LanternProxyingTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void test() throws Exception {
        final String[] urls = getUrls();
        final int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
        //Launcher.main(new String[]{"--disable-ui", "--disable-lae", "--force-get", "--user", "lanternuser@gmail.com", "--pass", "aKD13DAWd82"});
        Launcher.main(new String[]{"--disable-ui", "--force-get", "--user", "lanternuser@gmail.com", "--pass", "aKD13DAWd82"});
        
        // Give it a second to start up.
        Thread.sleep(3000);
        
        final Proxy proxy = new Proxy();
        proxy.setProxyType(Proxy.ProxyType.MANUAL);
        String proxyStr = String.format("localhost:%d", port);
        proxy.setHttpProxy(proxyStr);
        proxy.setSslProxy(proxyStr);

        final DesiredCapabilities capability = DesiredCapabilities.firefox();
        capability.setCapability(CapabilityType.PROXY, proxy);

        //final String urlString = "http://www.yahoo.com/";
        
        
        for (final String url : urls) {
            System.out.println("TESTING URL: "+url);
            // Note this will actually launch a browser!!
            final WebDriver driver = new FirefoxDriver(capability);
            driver.manage().timeouts().pageLoadTimeout(10, TimeUnit.SECONDS);
            driver.get(url);
            final String source = driver.getPageSource();
            //System.out.println(logs.);
            
            driver.close();
            
            // Just make sure it got something within reason.
            assertTrue(source.length() > 100);
        }

        //proxyServer.stop();
    }

    private String[] getUrls() {
        return new String[] {
            //"http://advar-news.biz/",
            //"http://advar-news.biz/local/cache-css/spip_style.c225_rtl.css",
            "http://advar-news.biz/local/cache-css/spip_formulaires.34a0_rtl.css",
            "http://advar-news.biz/extensions/porte_plume/css/barre_outils.css",
            "http://advar-news.biz/spip.php?page=boutonstexte.css",
            "http://advar-news.biz/spip.php?page=css_nivoslider",
            "http://advar-news.biz/spip.php?page=barre_outils_icones.css",
            "http://advar-news.biz/spip.php?page=boutonstexte-print.css",
            "http://advar-news.biz/local/cache-css/habillage.f9d4_rtl.css",
            "http://advar-news.biz/local/cache-css/impression.10b6_rtl.css",
            "http://advar-news.biz/prive/javascript/jquery.js",
            "http://advar-news.biz/prive/javascript/jquery.form.js",
            "http://advar-news.biz/prive/javascript/ajaxCallback.js",
            "http://advar-news.biz/prive/javascript/jquery.cookie.js",
            "http://advar-news.biz/extensions/porte_plume/javascript/xregexp-min.js",
            "http://advar-news.biz/extensions/porte_plume/javascript/jquery.markitup_pour_spip.js",
            "http://advar-news.biz/extensions/porte_plume/javascript/jquery.previsu_spip.js",
            "http://advar-news.biz/spip.php?page=porte_plume_start.js&lang=fa",
            "http://advar-news.biz/plugins/auto/boutonstexte/boutonstexte.js",
            "http://advar-news.biz/plugins/auto/nivoslider/js/jquery.nivo.slider.pack.js",
            "http://advar-news.biz/lib/jquery.fancybox-1.3.4/fancybox/jquery.fancybox-1.3.4.js",
            "http://advar-news.biz/plugins/auto/fancybox/javascript/fancybox.js",
            "http://advar-news.biz/lib/jquery.fancybox-1.3.4/fancybox/jquery.fancybox-1.3.4.css",
            "http://advar-news.biz/local/cache-vignettes/L800xH80/siteon0-dc90f.gif",
            "http://advar-news.biz/squelettes-dist/feed.png",
            "http://advar-news.biz/plugins/auto/outils_article/img_pack/textLarger.gif",
            "http://advar-news.biz/plugins/auto/outils_article/img_pack/textSmaller.gif",
            "http://advar-news.biz/local/cache-vignettes/L79xH100/moton548-bec1f.jpg",
            "http://advar-news.biz/local/cache-vignettes/L67xH100/moton443-2351d.jpg",
            "http://advar-news.biz/local/cache-vignettes/L88xH100/moton579-a152a.png",
            "http://advar-news.biz/local/cache-vignettes/L87xH100/moton56-4e869.jpg",
            "http://advar-news.biz/local/cache-vignettes/L72xH100/moton256-77c29.jpg",
            "http://advar-news.biz/local/cache-vignettes/L77xH100/moton166-84cfa.jpg",
            "http://advar-news.biz/local/cache-vignettes/L67xH100/moton559-cae2d.jpg",
            "http://advar-news.biz/local/cache-vignettes/L140xH100/moton562-3123d.jpg",
            "http://advar-news.biz/local/cache-vignettes/L75xH100/moton107-cc037.jpg",
            "http://advar-news.biz/local/cache-vignettes/L200xH134/arton13519-ab29d.jpg",
            "http://advar-news.biz/local/cache-vignettes/L300xH199/arton13536-d659c.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH54/arton13528-373c1.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH80/arton13516-24127.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH55/arton13508-e4fc6.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH54/arton13498-f1d12.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH56/arton13493-a53b8.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH60/arton13489-f5935.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH63/arton13475-f919d.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH53/arton13536-458bf.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH30/arton13534-9188c.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH66/arton13533-c3f7c.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH70/arton13537-c0337.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH57/arton13531-b1a47.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH80/arton13529-1cdde.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH55/arton13527-67492.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH54/arton13525-b67da.jpg",
            "http://advar-news.biz/local/cache-vignettes/L71xH80/arton13522-2ba45.jpg",
            "http://advar-news.biz/local/cache-vignettes/L67xH80/arton13506-98687.jpg",
            "http://advar-news.biz/local/cache-vignettes/L46xH80/arton13502-41406.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH60/arton13499-9bb74.jpg",
            "http://advar-news.biz/local/cache-vignettes/L80xH64/arton13497-63dea.jpg",
            "http://advar-news.biz/local/cache-vignettes/L53xH80/arton13514-80265.jpg",
        };
    }

}
