package org.lantern;

import static org.junit.Assert.assertEquals;

import java.io.FileReader;
import java.io.IOException;
import java.util.Collection;
import java.util.TreeSet;

import org.apache.commons.io.IOUtils;
import org.junit.Test;

public class PacFileGeneratorTest {

    
    @Test
    public void testGeneratePacFile() throws Exception {
        final Collection<String> sites = getEntries();
        final String pac = PacFileGenerator.generatePacFileString(sites);
        
        final String refPac = loadRefPac();
        assertEquals(refPac, pac);
    }
     

    private Collection<String> getEntries() {
        final Collection<WhitelistEntry> entries = new Whitelist().getEntries();
        final Collection<String> parsed = 
            new TreeSet<String>(String.CASE_INSENSITIVE_ORDER);
        for (final WhitelistEntry entry : entries) {
            final String str = entry.getSite();
            parsed.add(str);
        }
        return parsed;
    }


    private String loadRefPac() throws IOException {
        return IOUtils.toString(
            new FileReader("src/test/resources/proxy_on.pac.test"));
    }   
}
