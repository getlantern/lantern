package org.lantern.util;

import static org.junit.Assert.*;

import org.junit.Test;

public class CounterTest {
    @Test
    public void testCounter() throws Exception {
        Counter counter = Counter.averageOverOneSecond();
        assertEquals("Total starts at 0", 0, counter.getTotal());
        assertEquals("Rate starts at 0", 0,
                counter.getRate());

        counter.add(20);
        counter.add(40);
        assertEquals("Total reflects all added bytes", 60,
                counter.getTotal());

        long priorRate = Long.MAX_VALUE;
        for (int i = 0; i < 5; i++) {
            Thread.sleep(150);
            assertTrue("Rate is non-zero during moving window",
                    counter.getRate() > 0);
            assertTrue("Rate is decreasing during moving window",
                    counter.getRate() < priorRate);
            priorRate = counter.getRate();
        }

        Thread.sleep(1000);
        assertEquals(
                "Rate converges to zero after inactivity", 0,
                counter.getRate());
    }
}
