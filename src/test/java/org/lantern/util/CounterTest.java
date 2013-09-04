package org.lantern.util;

import static org.junit.Assert.*;

import org.junit.Test;
import org.lantern.util.Counter.CounterSnapshotter;

public class CounterTest {
    @Test
    public void testCounter() throws Exception {
        long period = 1000;
        long time = 30000;
        
        CounterSnapshotter snapshotter = new CounterSnapshotter();
        snapshotter.start();
        try {
            Counter counter = new Counter();
            assertEquals("Total starts at 0", 0, counter.getTotal());
            assertEquals("Rate starts at 0", 0,
                    counter.getAverageRateOver(period, time));

            counter.add(20);
            counter.add(40);
            assertEquals("Total reflects all added bytes", 60,
                    counter.getTotal());
            assertEquals(
                    "Rate is not updated until enough time has passed", 0,
                    counter.getAverageRateOver(period, time));
//
            Thread.sleep(2000);
            System.out.println(counter.getAverageRateOver(period, time));
            assertTrue("Rate is updated after enough time has passed",
                    counter.getAverageRateOver(period, time) > 0);
            assertEquals(
                    "Rate for teeny window is 0", 0,
                    counter.getAverageRateOver(period, 1));
        } finally {
            snapshotter.stop();
        }
    }
}
