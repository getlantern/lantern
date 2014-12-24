package org.lantern.util;

import static org.junit.Assert.*;

import org.junit.Test;

public class HashedTest {

    @Test
    public void testHash() {
        String hashHex = new Hashed("salty dog".getBytes(),
                "my data".getBytes(), 2000).hashHex();
        assertEquals(
                "5c1b78d152ce294512e4963ccede6968064426d783627782a89faa9e437c13af",
                hashHex);
    }
}
