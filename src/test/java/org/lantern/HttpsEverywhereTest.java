package org.lantern;

import static org.junit.Assert.*;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

import javax.xml.xpath.XPathExpressionException;

import org.junit.Test;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.littleshoot.util.xml.XPathUtils;
import org.littleshoot.util.xml.XmlUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.xml.sax.SAXException;


public class HttpsEverywhereTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test public void testHttpsEverywhereRegex() throws Exception {
        //HttpsEverywhere.toHttps("http://www.balatarin.com/test");
        final String[] urls = new String[] {
            "http://www.balatarin.com/test",
            "http://www.facebook.com/testing?query=test",
            "http://www.flickr.com/newPicture.jpg",
            "http://www.google.com/",
            "http://platform.linkedin.com/",
        };
        
        final String[] expecteds = new String[] {
            "https://balatarin.com/test",
            "https://www.facebook.com/testing?query=test",
            "https://secure.flickr.com/newPicture.jpg",
            "https://encrypted.google.com/",
            "https://platform.linkedin.com/",
        };
        for (int i = 0; i < urls.length; i++) {
            final String request = urls[i];
            final String expected = expecteds[i];
            final String converted = HttpsEverywhere.toHttps(request);//HttpsEverywhere.toHttps("Balatarin.xml", urls[i]);
            log.info("Got converted: "+converted);
            assertEquals(expected, converted);
        }
        
        final String[] excluded = new String[] {
            "http://www.google.com/search?tbm=isch",
            "http://test.forums.wordpress.com/"
        };
        
        for (int i = 0; i < excluded.length; i++) {
            final String request = excluded[i];
            final String converted = HttpsEverywhere.toHttps(request);//HttpsEverywhere.toHttps("Balatarin.xml", urls[i]);
            log.info("Got converted: "+converted);
            assertEquals(request, converted);
        }
        
        
        /*
        final String request = "http://images.google.com/testing?testing=testing";
        final String converted = HttpsEverywhere.toHttps("GoogleImages.xml", request);
        System.out.println("Converted: "+converted);
        assertTrue(converted.startsWith("https://encrypted.google.com"));
        */
        
        /*
        final File gi = new File("GoogleImages.xml");
        final InputStream is = new FileInputStream(gi);
        final Document doc = XmlUtils.toDoc(is);
        final XPathUtils utils = XPathUtils.newXPath(doc);
        final NodeList nameNodes = utils.getNodes("/ruleset/rule/@from");
        System.out.println(nameNodes.getLength());
        for (int i = 0; i < nameNodes.getLength(); i++) {
            final Node node = nameNodes.item(i);
            //final String name = node.getTextContent();
            final String from = node.getNodeValue();
            System.out.println(from);
            final String request = "http://images.google.com/testing?testing=testing";
            final String converted = HttpsEverywhere.toHttps("GoogleImages.xml", request);
        }
        */
    }
    
    private static String toHttps(final String file, final String request) 
        throws XPathExpressionException, IOException, SAXException {
        final File gi = new File(file);
        final InputStream is = new FileInputStream(gi);
        final Document doc = XmlUtils.toDoc(is);
        final XPathUtils utils = XPathUtils.newXPath(doc);
        final String from = utils.getString("/ruleset/rule/@from");
        //final String from = "^http://(images|www|encrypted)\\.google\\.com/(.*)";
        final String to = utils.getString("/ruleset/rule/@to");
        System.out.println(from);
        System.out.println(to);
        return request.replaceAll(from, to);
        /*
        System.out.println(nameNodes.getLength());
        for (int i = 0; i < nameNodes.getLength(); i++) {
            final Node node = nameNodes.item(i);
            //final String name = node.getTextContent();
            final String from = node.getNodeValue();
            System.out.println(from);
            final String request = "http://images.google.com/testing?testing=testing";
            final String converted = HttpsEverywhere.toHttps("GoogleImages.xml", request);
        }
        */
    }
}
