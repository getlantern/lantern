package org.lantern.util;

import static org.junit.Assert.*;

import org.junit.Test;
import org.lantern.util.ByteCounter.ByteCounterCalculator;

public class ByteCounterTest {
    @Test
    public void testByteCounter() throws Exception {
        ByteCounterCalculator calculator = new ByteCounterCalculator();
        calculator.start();
        try {
            ByteCounter counter = new ByteCounter();
            assertEquals("Total starts at 0", 0, counter.getTotalBytes());
            assertEquals("BPS starts at 0", 0,
                    counter.getCurrentBytesPerSecond());

            counter.add(20);
            counter.add(40);
            assertEquals("Total reflects all added bytes", 60,
                    counter.getTotalBytes());
            assertEquals(
                    "BPS is not updated until enough time has passed", 0,
                    counter.getCurrentBytesPerSecond());

            Thread.sleep(7000);
            assertTrue("BPS is updated after enough time has passed",
                    counter.getCurrentBytesPerSecond() > 0);
        } finally {
            calculator.stop();
        }
    }
}
