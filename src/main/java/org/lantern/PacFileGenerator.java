package org.lantern;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Collection;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for generating new pac files based on which sites Lantern should proxy.
 */
public class PacFileGenerator {

    private final static Logger LOG = 
        LoggerFactory.getLogger(PacFileGenerator.class);
    
    /**
     * Generates a pac file from the specified sites using a template.
     * 
     * @param sites The sites to proxy in the pac file.
     * @return The new pac file string.
     */
    public static String generatePacFileString(final Collection<String> sites) {
        final StringBuilder sb = new StringBuilder();

        final String template = loadTemplate();
        
        for (final String site : sites) {
            sb.append("proxyDomains[i++] = \"");
            sb.append(site);
            sb.append("\";\n");
        }
        return template.replace("allDomainsTok", sb.toString().trim());
    }

    private static String loadTemplate() {
        final File file = new File("src/main/resources/proxy_on.pac.template");
        if (!file.isFile()) {
            try {
                return LanternUtils.fileInJarToString("proxy_on.pac.template");
            } catch (final IOException e) {
                throw new Error("Could not load template from jar!!", e);
            }
        }
        FileReader fr = null;
        try {
            fr = new FileReader(file);
            return IOUtils.toString(fr);
        } catch (final IOException e) {
            
        } finally {
            IOUtils.closeQuietly(fr);
        }
        LOG.error("Could not load template!!");
        throw new Error("Could not load template!!");
    }

    public static void generatePacFile(final Collection<String> entries, 
        final File proxyOn) {
        LOG.debug("Writing pac file to: {}", proxyOn);
        final String pac = generatePacFileString(entries);
        FileWriter fw = null;
        try {
            fw = new FileWriter(proxyOn);
            fw.write(pac);
        } catch (final IOException e) {
            LOG.error("Could not write to pac file at: {}", proxyOn);
        } finally {
            IOUtils.closeQuietly(fw);
        }
    }

}
