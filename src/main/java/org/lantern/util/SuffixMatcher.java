package org.lantern.util;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

/**
 * Like {@link PrefixMatcher}, but matches suffixes instead of prefixes.
 */
public class SuffixMatcher {
    private PrefixMatcher prefixMatcher;

    public SuffixMatcher() {
        this(Collections.EMPTY_LIST);
    }

    public SuffixMatcher(Collection<String> strings) {
        this.prefixMatcher = new PrefixMatcher(reversed(strings));
    }

    public String longestMatchingSuffix(String string) {
        return reversed(prefixMatcher.longestMatchingPrefix(reversed(string)));
    }

    private static Collection<String> reversed(Collection<String> orig) {
        List<String> reversed = new ArrayList<String>();
        for (String str : orig) {
            reversed.add(reversed(str));
        }
        return reversed;
    }

    private static String reversed(String str) {
        if (str == null) {
            return null;
        }
        return new StringBuilder(str).reverse().toString();
    }
}
