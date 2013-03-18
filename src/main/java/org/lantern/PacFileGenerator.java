package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
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
    
    private PacFileGenerator() {}
    
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
                LOG.error("Could not extract pac template?", e);
                throw new Error("Could not load template from jar!!", e);
            }
        }
        FileInputStream fr = null;
        try {
            fr = new FileInputStream(file);
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
        OutputStream os = null;
        try {
            os = new FileOutputStream(proxyOn);
            os.write(pac.getBytes(LanternConstants.UTF8));
        } catch (final IOException e) {
            LOG.error("Could not write to pac file at: {}", proxyOn);
        } finally {
            IOUtils.closeQuietly(os);
        }
    }

}
