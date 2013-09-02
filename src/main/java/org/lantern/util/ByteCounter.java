package org.lantern.util;

import java.lang.ref.WeakReference;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

import org.lantern.LanternService;

/**
 * <p>
 * Counts bytes, providing statistics on total bytes as well as a constantly
 * updating bytesPerSecond.
 * </p>
 * 
 * <p>
 * Note - for bytesPerSecond to get calculated, you need to start a
 * {@link ByteCounterCalculator}.
 * </p>
 */
public class ByteCounter {
    private static final Queue<WeakReference<ByteCounter>> ALL_BYTES_COUNTERS = new ConcurrentLinkedQueue<WeakReference<ByteCounter>>();

    private final AtomicReference<Count> mostRecentCount = new AtomicReference<Count>(
            new Count());
    private final AtomicReference<Count> lastAveragedCount = new AtomicReference<Count>(
            mostRecentCount.get());
    private final AtomicLong currentBytesPerSecond = new AtomicLong(0);

    public ByteCounter() {
        ALL_BYTES_COUNTERS.add(new WeakReference<ByteCounter>(this));
    }

    /**
     * Add the given numberOfBytes to this counter.
     * 
     * @param numberOfBytes
     */
    public void add(long numberOfBytes) {
        Count mostRecent = mostRecentCount.get();
        Count next = new Count(mostRecent, numberOfBytes);
        // Run compareAndSet() until we've successfully updated the most recent
        // count
        while (!mostRecentCount.compareAndSet(mostRecent, next)) {
            mostRecent = mostRecentCount.get();
            next = new Count(mostRecent, numberOfBytes);
        }
    }

    /**
     * Returns the total bytes counted.
     * 
     * @return
     */
    public long getTotalBytes() {
        return mostRecentCount.get().totalBytes;
    }

    /**
     * Returns the bytesPerSecond moving average for the current period.
     * 
     * @return
     */
    public long getCurrentBytesPerSecond() {
        return currentBytesPerSecond.get();
    }

    /**
     * Calculate the BPS value for the current interval.
     */
    synchronized void calculateCurrentBytesPerSecond() {
        Count mostRecent = mostRecentCount.get();
        Count lastAverage = lastAveragedCount.get();
        double bytesSinceLastAverage = mostRecent.totalBytes
                - lastAverage.totalBytes;
        // Add 1 millisecond to avoid dividing by zero
        double millisSinceLastAverage = mostRecent.timestamp + 1
                - lastAverage.timestamp;
        millisSinceLastAverage = Math.max(millisSinceLastAverage, 1);
        currentBytesPerSecond.set((long) (bytesSinceLastAverage * 1000
                / millisSinceLastAverage));
    }

    /**
     * Represents a total count at a point in time.
     */
    private static class Count {
        final long timestamp = System.currentTimeMillis();
        final long totalBytes;

        Count() {
            this.totalBytes = 0;
        }

        Count(Count previous, long newBytes) {
            this.totalBytes = previous.totalBytes + newBytes;
        }
    }

    /*
     * <p>Calculates bytesPerSecond for all {@link ByteCounter}s.</p>
     */
    public static class ByteCounterCalculator implements LanternService {
        /**
         * How frequently to calculate moving averages.
         */
        private long calculationFrequencyInMillis = 5000;
        private ScheduledExecutorService executor;

        @Override
        public void start() throws Exception {
            executor = Executors.newSingleThreadScheduledExecutor();
            executor.scheduleAtFixedRate(
                    new Runnable() {
                        @Override
                        public void run() {
                            for (WeakReference<ByteCounter> counterRef : ByteCounter.ALL_BYTES_COUNTERS) {
                                ByteCounter counter = counterRef.get();
                                if (counter != null) {
                                    counter.calculateCurrentBytesPerSecond();
                                }
                            }
                        }
                    }, calculationFrequencyInMillis,
                    calculationFrequencyInMillis,
                    TimeUnit.MILLISECONDS);
        }

        @Override
        public void stop() {
            executor.shutdownNow();
        }
    }
}
