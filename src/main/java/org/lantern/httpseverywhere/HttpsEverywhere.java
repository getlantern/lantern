package org.lantern.httpseverywhere;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import javax.xml.xpath.XPathExpressionException;

import org.lantern.LanternUtils;
import org.littleshoot.util.xml.XPathUtils;
import org.littleshoot.util.xml.XmlUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

public class HttpsEverywhere {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(HttpsEverywhere.class);
    
    private static final Map<String, Collection<HttpsRule>> httpsRules =
        new ConcurrentHashMap<String, Collection<HttpsRule>>();
    
    static {
        final File httpsDir = new File("https");
        final File[] ruleFiles = httpsDir.listFiles();
        for (final File ruleFile : ruleFiles) {
            try {
                addRuleFile(ruleFile);
            } catch (final XPathExpressionException e) {
                LOG.error("Could not load rule file: "+ruleFile, e);
            } catch (final IOException e) {
                LOG.error("Could not load rule file: "+ruleFile, e);
            } catch (final SAXException e) {
                LOG.error("Could not load rule file: "+ruleFile, e);
            }
        }
    }

    private static void addRuleFile(final File ruleFile) throws IOException, 
        SAXException, XPathExpressionException {
        final InputStream is = new FileInputStream(ruleFile);
        final Document doc = XmlUtils.toDoc(is);
        final XPathUtils utils = XPathUtils.newXPath(doc);
        //final NodeList nodes = utils.getNodes("/ruleset/target/@host");
        final Collection<String> targets = 
            utils.getStrings("/ruleset/target/@host");
        
        //final Collection<String> froms = utils.getStrings("/ruleset/rule/@from");
        //final String from = "^http://(images|www|encrypted)\\.google\\.com/(.*)";
        //final Collection<String> tos = utils.getStrings("/ruleset/rule/@to");
        
        final NodeList nodes = utils.getNodes("/ruleset/rule");
        final int length = nodes.getLength();
        
        for (final String cur : targets) {
            final Collection<HttpsRule> rules;
            LOG.info("Checking target: {}", cur);
            if (cur.endsWith(".*")) {
                LOG.info("Not yet supporting wildcard targets such as {}", cur);
                continue;
            }
            final String target;
            if (cur.startsWith("*.")) {
                target = cur.substring(2);
                LOG.info("Adding wildcard target: {}", target);
            } else {
                target = cur;
            }
            if (httpsRules.containsKey(target)) {
                rules = httpsRules.get(target);
            } else {
                rules = new ArrayList<HttpsRule>(length);
                httpsRules.put(target, rules);
            }
            for (int i = 0; i < length; i++) {
                final Node node = nodes.item(i);
                final NamedNodeMap attributes = node.getAttributes();
                final String from = 
                    attributes.getNamedItem("from").getTextContent();
                final String to = 
                    attributes.getNamedItem("to").getTextContent();
                final HttpsRule rule = new HttpsRule(from, to);
                rules.add(rule);
            }
        }
    }

    /*
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
            response.setHeader(HttpHeaders.Names.LOCATION, redirect);
            return response;
        }
    }
    */
    
    public static String toHttps(final String uri) {
        //final String toMatch = Whitelist.toBaseUri(uri);
        if (!uri.startsWith("http://")) {
            LOG.info("Not modifying non-http request: {}", uri);
            return uri;
        }
        final String toMatch = LanternUtils.toHost(uri);
        final String raw = LanternUtils.stripSubdomains(toMatch);

        LOG.info("URI: {}", toMatch);
        final Collection<HttpsRule> rules = getRules(toMatch, raw);
        if (rules == null) {
            
            LOG.info("NO RULES FOR {}", toMatch);
            return uri;
        } else {
            //LOG.info("Rewriting to HTTPS for base URI: {}", toMatch);
            //LOG.info("Got rules in: {}", httpsRules);
            //LOG.info("RULES: {}", rules);
            
            for (final HttpsRule rule : rules) {
                //LOG.info("Applying rule: {}", rule);
                final String modified = rule.apply(uri);
                if (!modified.equals(uri)) {
                    return modified;
                }
            }
            //return rule.apply(uri);
            return uri;
        }
    }

    private static Collection<HttpsRule> getRules(final String toMatch, 
        final String raw) {
        final Collection<HttpsRule> rules = httpsRules.get(toMatch);
        if (rules != null) {
            return rules;
        }
        return httpsRules.get(raw);
    }
}
