package org.lantern.util;

import static org.junit.Assert.*;

import java.util.Arrays;
import java.util.List;

import org.junit.Test;

public class PrefixMatcherTest {
    @Test
    public void test() {
        List<String> strings = Arrays.asList(new String[] {
                "a",
                "abc",
                "abcde",
                "abcx",
                "abcxy",
                "b",
                "bcd",
                "bcdef",
                "bcdy",
                "bcdyz",
                "bddd",
                "c",
                "cbe",
                "cbeda",
                "cbez",
                "cbezx"
        });
        PrefixMatcher matcher = new PrefixMatcher(strings);
        assertEquals("abcx", matcher.longestMatchingPrefix("abcxx"));
        assertEquals("a", matcher.longestMatchingPrefix("adeeee"));
        assertEquals("bcdyz", matcher.longestMatchingPrefix("bcdyzxxx"));
        assertEquals("cbe", matcher.longestMatchingPrefix("cbe"));
        assertNull(matcher.longestMatchingPrefix("ddd"));
    }

}
