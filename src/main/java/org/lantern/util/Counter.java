package org.lantern.util;

import java.lang.ref.WeakReference;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

import org.lantern.LanternService;

/**
 * <p>
 * Counts stuff, including keeping a total count as well as providing the
 * ability to calculate a moving average.
 * </p>
 * 
 * <p>
 * The moving average is calculated using a bounded list of periodic snapshots.
 * </p>
 * 
 * <p>
 * Note - for the moving average to get calculated, you need to start a
 * {@link CounterSnapshotter}.
 * </p>
 */
public class Counter {
    private static final Queue<WeakReference<Counter>> ALL_BYTES_COUNTERS = new ConcurrentLinkedQueue<WeakReference<Counter>>();

    private final long maximumHistoryAgeInMillis;
    private final AtomicLong total = new AtomicLong(0);
    private volatile Snapshot latestSnapshot = new Snapshot();

    /**
     * Create a counter that keeps a history (for running averages) up to the
     * given age.
     * 
     * @param maximumHistoryAgeInMillis
     */
    public Counter(long maximumHistoryAgeInMillis) {
        this.maximumHistoryAgeInMillis = maximumHistoryAgeInMillis;
        ALL_BYTES_COUNTERS.add(new WeakReference<Counter>(this));
    }

    /**
     * Create a counter that keeps 1 minute worth of history.
     */
    public Counter() {
        this(60000);
    }

    /**
     * Add the given count
     * 
     * @param delta
     */
    public void add(long delta) {
        total.addAndGet(delta);
    }

    /**
     * Gets the total count over all time.
     * 
     * @return
     */
    public long getTotal() {
        return total.get();
    }

    /**
     * Get the average rate over the given period of time
     * 
     * @param ratePeriodInMillis
     *            the period for calculating the rate (e.g. every second)
     * @return timeInMillis how far back to look starting from now
     */
    public long getAverageRateOver(long ratePeriodInMillis, long timeInMillis) {
        long now = System.currentTimeMillis();
        long cutoff = now - timeInMillis;
        long currentTotal = total.get();
        long previousTotal = currentTotal;
        long previousTimestamp = now;

        // Find the oldest total that we can from the available snapshots
        Snapshot snapshot = latestSnapshot;
        while (snapshot != null) {
            if (snapshot.timestamp < cutoff) {
                break;
            }
            previousTotal = snapshot.total;
            previousTimestamp = snapshot.timestamp;
            snapshot = snapshot.prior;
        }

        double timeDelta = now - previousTimestamp;
        if (timeDelta == 0) {
            return 0;
        }

        double delta = currentTotal - previousTotal;
        return (long) (delta * ratePeriodInMillis / timeDelta);
    }

    void snapshot() {
        latestSnapshot = new Snapshot(latestSnapshot, total.get());
        // Prune snapshots older than our configured maximum history age
        long cutoff = latestSnapshot.timestamp - maximumHistoryAgeInMillis;
        Snapshot laterSnapshot = latestSnapshot;
        Snapshot snapshot;
        while ((snapshot = laterSnapshot.prior) != null) {
            if (snapshot.timestamp < cutoff) {
                laterSnapshot.prior = null;
                break;
            }
            laterSnapshot = snapshot;
        }
    }

    /**
     * Represents a snapshot of the count at a point in time
     */
    private static class Snapshot {
        final long timestamp = System.currentTimeMillis();
        final long total;
        volatile Snapshot prior;

        private Snapshot() {
            this.total = 0;
        }

        private Snapshot(Snapshot prior, long total) {
            this.prior = prior;
            this.total = total;
        }
    }

    /*
     * <p>Takes snapshots for all {@link Counter}s.</p>
     */
    public static class CounterSnapshotter implements LanternService {
        /**
         * How frequently to snapshot
         */
        private long snapshotFrequencyInMillis = 100;
        private ScheduledExecutorService executor;

        @Override
        public void start() throws Exception {
            executor = Executors.newSingleThreadScheduledExecutor();
            executor.scheduleAtFixedRate(
                    new Runnable() {
                        @Override
                        public void run() {
                            for (WeakReference<Counter> counterRef : Counter.ALL_BYTES_COUNTERS) {
                                Counter counter = counterRef.get();
                                if (counter != null) {
                                    counter.snapshot();
                                }
                            }
                        }
                    }, snapshotFrequencyInMillis,
                    snapshotFrequencyInMillis,
                    TimeUnit.MILLISECONDS);
        }

        @Override
        public void stop() {
            executor.shutdownNow();
        }
    }
}
