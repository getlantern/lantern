package org.lantern;

import static org.junit.Assert.assertEquals;

import org.junit.Ignore;
import org.junit.Test;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Ignore
public class HttpsEverywhereTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test public void testHttpsEverywhereRegex() throws Exception {
        final String[] urls = new String[] {
            "http://www.gmail.com/test",
            "http://news.google.com/news",
            "http://www.google.com.testing/",
            "http://www.balatarin.com/test",
            "http://www.facebook.com/testing?query=test",
            "http://www.flickr.com/newPicture.jpg",
            "http://www.google.com/",
            "http://www.twitter.com/",
            "http://platform.linkedin.com/",
        };
        
        final String[] expecteds = new String[] {
            "https://mail.google.com/test",
            "https://www.google.com/news",
             // This should be the same -- it should match the *target* for 
             // http://www.google.com.* but there is no relevant rule.
            "http://www.google.com.testing/", 
            "https://balatarin.com/test",
            "https://www.facebook.com/testing?query=test",
            "https://secure.flickr.com/newPicture.jpg",
            "https://encrypted.google.com/",
            "https://twitter.com/",
            "https://platform.linkedin.com/",
        };
        final HttpsEverywhere he = new HttpsEverywhere();
        for (int i = 0; i < urls.length; i++) {
            final String request = urls[i];
            final String expected = expecteds[i];
            final String converted = he.toHttps(request);
            log.info("Got converted: "+converted);
            assertEquals(expected, converted);
        }
        
        final String[] excluded = new String[] {
            "http://images.google.com/",
            "http://test.forums.wordpress.com/"
        };
        
        for (int i = 0; i < excluded.length; i++) {
            final String request = excluded[i];
            final String converted = he.toHttps(request);
            log.info("Got converted: "+converted);
            assertEquals(request, converted);
        }
    }
}
