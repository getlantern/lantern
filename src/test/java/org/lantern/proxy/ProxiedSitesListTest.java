package org.lantern.proxy;

import static org.junit.Assert.*;

import org.junit.Test;

public class ProxiedSitesListTest {
    @Test
    public void test() {
        String[] strings = new String[] {
                "google.com",
                "www.google.com",
                "com",
                "127.0.0.5"
        };
        ProxiedSitesList list = new ProxiedSitesList(strings);
        assertTrue(list.includes("www.google.com"));
        assertTrue(list.includes("google.com"));
        assertTrue(list.includes("mail.google.com"));
        assertTrue(list.includes("osnews.com"));
        assertFalse(list.includes("google"));
        assertFalse(list.includes("help.org"));
        assertFalse(list.includes(""));
        assertTrue(list.includes("127.0.0.5"));
        assertFalse(list.includes("128.0.0.5"));
    }
}
