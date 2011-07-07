package org.lantern.httpseverywhere;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import javax.xml.xpath.XPathExpressionException;

import org.eclipse.jetty.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.DefaultHttpResponse;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.lantern.Whitelist;
import org.littleshoot.util.xml.XPathUtils;
import org.littleshoot.util.xml.XmlUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.xml.sax.SAXException;

public class HttpsEverywhere {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(HttpsEverywhere.class);
    
    private static Map<String, HttpsRule> httpsRules =
        new ConcurrentHashMap<String, HttpsRule>();

    public static String toHttps(final String file, final String request) 
        throws XPathExpressionException, IOException, SAXException {
        final File gi = new File(file);
        final InputStream is = new FileInputStream(gi);
        final Document doc = XmlUtils.toDoc(is);
        final XPathUtils utils = XPathUtils.newXPath(doc);
        final String from = utils.getString("/ruleset/rule/@from");
        final String to = utils.getString("/ruleset/rule/@to");
        System.out.println(from);
        System.out.println(to);
        return "";
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

    public static HttpResponse toHttps(final HttpRequest request) {
        final String uri = request.getUri();
        final String toMatch = Whitelist.toBaseUri(uri);
        final HttpsRule rule = httpsRules.get(toMatch);
        if (rule == null) {
            LOG.info("No HTTPS match for base URI: {}", toMatch);
            return null;
        } else {
            LOG.info("Rewriting to HTTPS for base URI: {}", toMatch);
            final String redirect = rule.apply(request);
            final HttpResponse response = 
                new DefaultHttpResponse(request.getProtocolVersion(), 
                    HttpResponseStatus.TEMPORARY_REDIRECT);
            response.setHeader(HttpHeaders.LOCATION, redirect);
            return response;
        }
    }

}
