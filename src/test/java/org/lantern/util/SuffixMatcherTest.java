package org.lantern.util;

import static org.junit.Assert.*;

import java.util.Arrays;
import java.util.List;

import org.junit.Test;

public class SuffixMatcherTest {
    @Test
    public void test() {
        List<String> strings = Arrays.asList(new String[] {
                "google.com",
                "www.google.com",
                "com"
        });
        SuffixMatcher matcher = new SuffixMatcher(strings);
        assertEquals("www.google.com",
                matcher.longestMatchingSuffix("www.google.com"));
        assertEquals("google.com", matcher.longestMatchingSuffix("google.com"));
        assertEquals("google.com",
                matcher.longestMatchingSuffix("mail.google.com"));
        assertEquals("com", matcher.longestMatchingSuffix("osnews.com"));
        assertNull(matcher.longestMatchingSuffix("google"));
        assertNull(matcher.longestMatchingSuffix(""));
        
        matcher = new SuffixMatcher();
        assertNull(matcher.longestMatchingSuffix("www.google.com"));
        assertNull(matcher.longestMatchingSuffix(""));
    }

}
