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
        final Collection<String> sites = new Whitelist().getEntriesAsStrings();
        final String pac = PacFileGenerator.generatePacFileString(sites);
        
        final String refPac = loadRefPac();
        assertEquals(refPac, pac);
    }


    private String loadRefPac() throws IOException {
        return IOUtils.toString(
            new FileReader("src/test/resources/proxy_on.pac.test"));
    }   
}
