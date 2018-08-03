package org.lantern.util;

import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.SortedSet;
import java.util.TreeSet;

/**
 * A Trie that you can check for the {@link #longestMatchingPrefix(String)} of a
 * given string.
 */
public class PrefixMatcher {
    private final Node root = new Node((char) 0);

    public PrefixMatcher(Collection<String> strings) {
        // Build a Trie
        SortedSet<String> sortedStrings = new TreeSet<String>(strings);
        for (String string : sortedStrings) {
            Node node = root;
            for (char c : string.toCharArray()) {
                node = node.childFor(c);
            }
            // The last node is the one that has a value
            node.hasValue = true;
        }
    }

    /**
     * Search our Trie for the longest matching sequence of characters out of
     * the given string.
     * 
     * @param string
     * @return
     */
    public String longestMatchingPrefix(String string) {
        Search search = new Search(string);
        root.search(search);
        return search.longestMatch();
    }

    @Override
    public String toString() {
        return "PrefixMatcher\n-----------------\n" + root.toString();
    }

    /**
     * A node in a 1 character per node trie.
     */
    private static class Node {
        private final char c;
        private final Map<Character, Node> children = new HashMap<Character, Node>();
        private volatile boolean hasValue;

        private Node(char c) {
            this.c = c;
        }

        private Node childFor(char c) {
            Node child = children.get(c);
            if (child == null) {
                child = new Node(c);
                children.put(c, child);
            }
            return child;
        }

        private void search(Search search) {
            Node node = this;
            while (search.hasMoreChars()) {
                char nextChar = search.nextChar();
                Node child = node.children.get(nextChar);
                if (child == null) {
                    break;
                }
                if (child.hasValue) {
                    search.matched();
                }
                node = child;
            }
        }

        @Override
        public String toString() {
            StringBuilder builder = new StringBuilder();
            toString(builder, 0);
            return builder.toString();
        }

        private void toString(StringBuilder builder, int indentation) {
            if (c != (char) 0) {
                for (int i = 0; i < indentation; i++) {
                    builder.append("  ");
                }
                builder.append(c);
                if (hasValue) {
                    builder.append("*");
                }
                builder.append("\n");
                indentation += 1;
            }
            for (Node child : children.values()) {
                child.toString(builder, indentation);
            }
        }
    }

    private static class Search {
        private final char[] chars;
        private volatile int currentChar = 0;
        private volatile int longestMatchedChar = 0;

        private Search(String string) {
            chars = string.toCharArray();
        }

        private char nextChar() {
            return chars[currentChar++];
        }

        private boolean hasMoreChars() {
            return currentChar < chars.length;
        }

        private void matched() {
            longestMatchedChar = currentChar;
        }

        private String longestMatch() {
            if (longestMatchedChar == 0) {
                return null;
            } else {
                return new String(
                        Arrays.copyOf(chars, longestMatchedChar));
            }
        }
    }
}
