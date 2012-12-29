package org.lantern;

import static org.junit.Assert.assertEquals;

import java.util.concurrent.TimeUnit;

import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.junit.Test;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.HttpRequestFilter;
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

    private static final Logger log = 
        LoggerFactory.getLogger(LanternProxyingTest.class);
    
    public static void main(final String[] args) throws Exception {
        //int port = 9090;
        //HttpProxyServer proxyServer = new DefaultHttpProxyServer(port);
        //proxyServer.start();
        
        Launcher launcher = new Launcher(new String[]{"--disable-trusted-peers", 
            "--disable-anon-peers", "--disable-ui", "--force-get", 
            "--user", TestUtils.loadTestEmail(), "--pass", 
            TestUtils.loadTestPassword()});
        launcher.run();

        Proxy proxy = new Proxy();
        proxy.setProxyType(Proxy.ProxyType.MANUAL);
        String proxyStr = String.format("localhost:%d", 
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        proxy.setHttpProxy(proxyStr);
        proxy.setSslProxy(proxyStr);

        final DesiredCapabilities capability = DesiredCapabilities.firefox();
        capability.setCapability(CapabilityType.PROXY, proxy);

        final String urlString = "http://www.facebook.com";
        final WebDriver driver = new FirefoxDriver(capability);
        driver.manage().timeouts().pageLoadTimeout(30, TimeUnit.SECONDS);

        driver.get(urlString);

        driver.close();
        log.info("Driver closed");

        //proxyServer.stop();
        log.info("Proxy stopped");
        //Launcher.stop();
        log.info("Finished with stop!!");
    }
    
    /*
    private static ChromeDriverService service;
    private WebDriver driver;
    
    @BeforeClass
    public static void createAndStartService() {
      service = new ChromeDriverService.Builder()
          .usingChromeDriverExecutable(new File("path/to/my/chromedriver"))
          .usingAnyFreePort()
          .build();
      service.start();
    }
    */

    @Test
    public void testWithHttpClient() throws Exception {
        //final String url = "http://www.yahoo.com";
        final String url = "http://www.facebook.com";
            //"https://rlanternz.appspot.com/http/advar-news.biz/local/cache-css/spip_formulaires.34a0_rtl.css";
                //"http://localhost:8080/http/advar-news.biz/local/cache-css/spip_formulaires.34a0_rtl.css";
            //    "http://advar-news.biz/local/cache-css/spip_formulaires.34a0_rtl.css";
        
        final int PROXY_PORT = 10200;
        final HttpClient client = new DefaultHttpClient();

        final HttpGet get = new HttpGet(url);
        //get.setHeader(HttpHeaders.Names.CONTENT_RANGE, "Range: bytes=0-1999999");
        //get.setHeader(HttpHeaders.Names.HOST, "rlanternz.appspot.com");
//        get.setHeader("Lantern-Version", "lantern_version_tok");
//        get.setHeader("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:15.0) Gecko/20100101 Firefox/15.0");
//        get.setHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
//        get.setHeader("Accept-Language", "en-us,en;q=0.5");
//        get.setHeader("Accept-Encoding", "gzip, deflate");
//        get.setHeader("Proxy-Connection", "keep-alive");
//        get.setHeader("Host", "rlanternz.appspot.com");
//        get.setHeader("Lantern-Version", "lantern_version_tok");
//        get.setHeader("Range", "bytes=0-1999999");
        
        HttpResponse response = client.execute(get);
        
        final Header[] headers = response.getAllHeaders();
        for (final Header h : headers) {
            log.debug(h.getName() + ": "+h.getValue());
        }
        //assertEquals(200, response.getStatusLine().getStatusCode());
        EntityUtils.consume(response.getEntity());

        final HttpProxyServer proxy = 
            new DefaultHttpProxyServer(PROXY_PORT, new HttpRequestFilter() {
            @Override
            public void filter(final HttpRequest httpRequest) {
                log.debug("Request went through proxy");
            }
        });

        proxy.start();
        client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, 
            new HttpHost("localhost", PROXY_PORT));
        response = client.execute(get);
        assertEquals(200, response.getStatusLine().getStatusCode());
        
        final HttpEntity entity = response.getEntity();
        log.debug("Received response: {}", IOUtils.toString(entity.getContent()));
        log.debug("Consuming entity");
        EntityUtils.consume(entity);
        
        log.debug("Stopping proxy");
        proxy.stop();
    }
    
    @Test
    public void testThroughLantern() throws Exception {
        //final String[] urls = {"https://rlanternz.appspot.com/http/advar-news.biz/local/cache-css/spip_formulaires.34a0_rtl.css"};//getUrls();
        final String[] urls = getUrls();
        //final String[] urls = {"http://www.yahoo.com/"};
        final int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;

        Launcher launcher = new Launcher(new String[] { "--disable-ui",
                "--force-get", "--user", TestUtils.loadTestEmail(), "--pass",
                TestUtils.loadTestPassword() });
        launcher.run();
        
        // Give it a second to start up.
        Thread.sleep(6000);
        
        final Proxy proxy = new Proxy();
        proxy.setProxyType(Proxy.ProxyType.MANUAL);
        String proxyStr = String.format("127.0.0.1:%d", port);
        //proxy.setHttpProxy(proxyStr);
        //proxy.setSslProxy(proxyStr);

        final DesiredCapabilities capability = DesiredCapabilities.firefox();
        //final DesiredCapabilities capability = DesiredCapabilities.chrome();
        //capability.setCapability("chrome.binary", "/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome");
        //capability.setCapability(CapabilityType.PROXY, proxy);

        //final String urlString = "http://www.yahoo.com/";
        for (final String url : urls) {
            log.info("TESTING URL: "+url);
            // Note this will actually launch a browser!!
            final WebDriver driver = new FirefoxDriver(capability);
            //final WebDriver driver = new ChromeDriver(capability);
            //final WebDriver driver = new HtmlUnitDriver(capability);
            driver.manage().timeouts().pageLoadTimeout(20, TimeUnit.SECONDS);
            final String source = driver.getPageSource();
            //final Navigation nav = driver.navigate();
            //System.out.println(logs.);
            
            driver.close();
            log.info("RESPONSE: "+source);
            log.info("RESPONSE LENGTH: "+source.length());
            // Just make sure it got something within reason.
            //assertTrue(source.length() > 100);
            
            // The following is sent to firefox when the proxy server is 
            // refusing connections. Note we can't get access to the response
            // code.
            //assertFalse("Proxy server not receiving connections?", 
            //    source.contains("!ENTITY securityOverride"));
        }
        log.info("Finished with test");
        //proxyServer.stop();
        //Launcher.stop();
        Thread.sleep(30000);
    }

    private String[] getUrls() {
        return new String[] {
            "https://www.facebook.com",
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
            /*
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
            */
            /*
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
            */
        };
    }

}
