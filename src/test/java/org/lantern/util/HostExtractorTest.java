package org.lantern.util;

import org.junit.Test;
import static org.junit.Assert.*;

public class HostExtractorTest {
    private static final String[] HOST_URLS = new String[] {
            "http://www.google.com",
            "http://www.google.com/",
            "http://www.google.com/humans.txt",
            "https://www.google.com",
            "https://www.google.com/",
            "https://www.google.com/humans.txt",
            "www.google.com:80", // like in a CONNECT request
            "http://www.google.com:80",
            "http://www.google.com:80/",
            "http://www.google.com:80/humans.txt",
            "https://www.google.com:443",
            "https://www.google.com:443/",
            "https://www.google.com:443/humans.txt",
    };
    
    private static final String[] IP_URLS = new String[] {
            "https://192.168.0.1",
            "https://192.168.0.1/",
            "https://192.168.0.1/humans.txt"
    };

    @Test
    public void testExtractHost() {
        for (String url : HOST_URLS) {
            assertEquals(String.format("Extracted correct host from %1$s", url), 
                    "www.google.com",
                    HostExtractor.extractHost(url));
        }
        
        for (String url : IP_URLS) {
            assertEquals(String.format("Extracted correct host from %1$s", url), 
                    "192.168.0.1",
                    HostExtractor.extractHost(url));
        }
    }
}
