package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.FileReader;
import java.io.IOException;
import java.util.Collection;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.junit.Test;

public class PacFileGeneratorTest {

    
    @Test
    public void testGeneratePacFile() throws Exception {
        final Collection<String> sites = new Whitelist().getEntriesAsStrings();
        final String pac = PacFileGenerator.generatePacFileString(sites);
        
        final String refPac = loadRefPac();
        
        
        for (final String site : sites) {
            assertTrue(pac.contains(site));
        }
        assertTrue(pac.startsWith(StringUtils.substringBefore(refPac, "allDomainsTok")));
        assertTrue(pac.endsWith(StringUtils.substringAfter(refPac, "allDomainsTok")));
    }


    private String loadRefPac() throws IOException {
        return IOUtils.toString(
            new FileReader("src/main/resources/proxy_on.pac.template"));
            //new FileReader("src/test/resources/proxy_on.pac.test"));
    }   
}
