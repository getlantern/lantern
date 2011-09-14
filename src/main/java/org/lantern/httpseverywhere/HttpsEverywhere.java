package org.lantern.httpseverywhere;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
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

/**
 * Class for converting requests to HTTPS when we can.
 */
public class HttpsEverywhere {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(HttpsEverywhere.class);
    
    private static final Map<String, HttpsRuleSet> httpsRules =
        new ConcurrentHashMap<String, HttpsRuleSet>();
    
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
        final Collection<String> targets = 
            utils.getStrings("/ruleset/target/@host");
        
        final Collection<String> exclusions = 
            utils.getStrings("/ruleset/exclusion/@pattern");
        
        final NodeList nodes = utils.getNodes("/ruleset/rule");
        final int length = nodes.getLength();
        
        for (final String target : targets) {
            LOG.info("Checking target: {}", target);
            final HttpsRuleSet ruleSet;
            if (httpsRules.containsKey(target)) {
                ruleSet = httpsRules.get(target);
            } else {
                ruleSet = new HttpsRuleSet(new ArrayList<HttpsRule>(length), exclusions);
                httpsRules.put(target, ruleSet);
            }
            for (int i = 0; i < length; i++) {
                final Node node = nodes.item(i);
                final NamedNodeMap attributes = node.getAttributes();
                final String from = 
                    attributes.getNamedItem("from").getTextContent();
                final String to = 
                    attributes.getNamedItem("to").getTextContent();
                final HttpsRule rule = new HttpsRule(from, to);
                ruleSet.rules.add(rule);
            }
        }
    }
    
    public static String toHttps(final String uri) {
        if (!uri.startsWith("http://")) {
            LOG.info("Not modifying non-http request: {}", uri);
            return uri;
        }
        final Collection<String> candidates = 
            LanternUtils.toHttpsCandidates(uri);
        //LOG.info("Candidates: {}", candidates);
        final Collection<HttpsRuleSet> ruleSets = getRules(candidates);
        if (ruleSets == null || ruleSets.isEmpty()) {
            LOG.info("NO RULES");
            return uri;
        } 
        for (final HttpsRuleSet ruleSet : ruleSets) {
            //LOG.info("Rewriting to HTTPS for base URI: {}", toMatch);
            //LOG.info("Got rules in: {}", httpsRules);
            //LOG.info("RULES: {}", rules);
            if (excluded(uri, ruleSet.exclusions)) {
                LOG.info("Excluding ignored URI: {}", uri);
                continue;
            }
            
            //LOG.info("Applying rules: {}", ruleSet.rules);
            for (final HttpsRule rule : ruleSet.rules) {
                //LOG.info("Applying rule: {}", rule);
                final String modified = rule.apply(uri);
                if (!modified.equals(uri)) {
                    LOG.info("Returning modified URL: {}", modified);
                    return modified;
                }
            }
        }
        
        LOG.info("Unchanged!");
        return uri;
    }

    private static boolean excluded(final String uri,
        final Collection<String> exclusions) {
        for (final String exclusion : exclusions) {
            if (uri.matches(exclusion)) {
                LOG.info("URI {} matches exclusion {}", uri, exclusion);
                return true;
            }
        }
        return false;
    }

    private static Collection<HttpsRuleSet> getRules(
        final Collection<String> candidates) {
        //LOG.info("Searching for rules in: {}", httpsRules);
        final Collection<HttpsRuleSet> rules = new HashSet<HttpsRuleSet>();
        for (final String candidate : candidates) {
            final HttpsRuleSet ruleSet = httpsRules.get(candidate);
            if (ruleSet != null) {
                rules.add(ruleSet);
            }
        }
        return rules;
    }
    
    
    private static final class HttpsRuleSet {
        private final Collection<HttpsRule> rules;
        private final Collection<String> exclusions;

        private HttpsRuleSet(final Collection<HttpsRule> rules, 
            final Collection<String> exclusions) {
            this.rules = rules;
            this.exclusions = exclusions;
        }
        
        @Override
        public String toString() {
            return "HttpsRuleSet [rules=" + rules + "]";
        }
    }
}
