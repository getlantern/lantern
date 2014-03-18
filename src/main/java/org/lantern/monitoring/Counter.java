package org.lantern.monitoring;

import java.lang.ref.WeakReference;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

import org.codehaus.jackson.annotate.JsonProperty;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.lantern.util.Threads;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * Counts stuff, including keeping a {@link #getTotal()} and a
 * {@link #getRate()} which is a moving average over
 * {@link #movingAverageWindowInMillis}.
 * </p>
 * 
 * <p>
 * To minimize overhead, moving rates are calculated approximately 10 times a
 * second, which means that they don't always reflect the most recent data
 * reported to {@link #add(long)}.
 * </p>
 */
public class Counter {
    private static final Logger LOG = LoggerFactory.getLogger(Counter.class);

    private static final Queue<WeakReference<Counter>> ALL_COUNTERS = new ConcurrentLinkedQueue<WeakReference<Counter>>();
    private static final int RATE_CALCULATION_INTERVAL_IN_MILLIS = 100;

    private final long movingAverageWindowInMillis;
    private final AtomicLong total = new AtomicLong(0);
    private final AtomicLong rate = new AtomicLong(0);
    private volatile Snapshot latestSnapshot = new Snapshot();
    private volatile AtomicLong lastCapturedTotal = new AtomicLong(0);

    /**
     * Create a counter that keeps a moving average over the given window.
     * 
     * @param movingAverageWindowInMillis
     */
    public Counter(long movingAverageWindowInMillis) {
        this.movingAverageWindowInMillis = movingAverageWindowInMillis;
        ALL_COUNTERS.add(new WeakReference<Counter>(this));
    }

    public Counter(
            @JsonProperty("movingAverageWindowInMillis") long movingAverageWindowInMillis,
            @JsonProperty("total") long total,
            @JsonProperty("lastCapturedTotal") long lastCapturedTotal) {
        this(movingAverageWindowInMillis);
        this.total.set(total);
        this.lastCapturedTotal.set(lastCapturedTotal);
        this.latestSnapshot = new Snapshot(null, total);
    }

    /**
     * Creates a {@link Counter} that maintains a 1-second moving average.
     * 
     * @return
     */
    public static Counter averageOverOneSecond() {
        return new Counter(1000);
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
    @JsonView({ Run.class, Persistent.class })
    public long getTotal() {
        return total.get();
    }

    @JsonView({ Run.class, Persistent.class })
    public long getLastCapturedTotal() {
        return lastCapturedTotal.get();
    }

    public long getMovingAverageWindowInMillis() {
        return movingAverageWindowInMillis;
    }
    
    /**
     * Get delta since last captureDelta().
     * 
     * @return
     */
    synchronized public long captureDelta() {
        long newTotal = total.get();
        long oldTotal = lastCapturedTotal.get();
        long delta = newTotal - oldTotal;
        lastCapturedTotal.set(newTotal);
        return delta;
    }

    /**
     * Gets the most recently computed rate averaged over a moving window of
     * {@link #movingAverageWindowInMillis}.
     * 
     * @return
     */
    public long getRate() {
        return rate.get();
    }

    /**
     * Resets this counter to 0.
     */
    synchronized public void reset() {
        total.set(0);
        rate.set(0);
        latestSnapshot = new Snapshot();
    }

    private void calculateRate() {
        latestSnapshot = new Snapshot(latestSnapshot, total.get());

        // Find the oldest snapshot within our moving window
        long cutoff = latestSnapshot.timestamp - movingAverageWindowInMillis;
        Snapshot oldestSnapshot = latestSnapshot;
        Snapshot laterSnapshot = latestSnapshot;
        Snapshot snapshot;
        while ((snapshot = laterSnapshot.prior) != null) {
            if (snapshot.timestamp < cutoff) {
                // We've moved past our moving window
                // Prune the snapshot
                laterSnapshot.prior = null;
                // Stop processing
                break;
            }
            oldestSnapshot = snapshot;
            laterSnapshot = snapshot;
        }

        // Calculate rate
        double timeDelta = latestSnapshot.timestamp - oldestSnapshot.timestamp;
        if (timeDelta == 0) {
            rate.set(0);
        } else {
            double delta = latestSnapshot.total - oldestSnapshot.total;
            rate.set((long) (delta * movingAverageWindowInMillis / timeDelta));
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

    static {
        // Periodically calculate rate for all Counters
        ScheduledExecutorService executor = Threads
                .newSingleThreadScheduledExecutor("Counter-Calculator");
        executor.scheduleAtFixedRate(
                new Runnable() {
                    @Override
                    public void run() {
                        try {
                            for (WeakReference<Counter> counterRef : Counter.ALL_COUNTERS) {
                                Counter counter = counterRef.get();
                                try {
                                    if (counter != null) {
                                        counter.calculateRate();
                                    }
                                } catch (Exception e) {
                                    LOG.error(
                                            "Unable to calculate rate for: {}",
                                            counter, e);
                                }
                            }
                        } catch (Exception e) {
                            LOG.error("Unable to calculate rates", e);
                        }
                    }
                }, RATE_CALCULATION_INTERVAL_IN_MILLIS,
                RATE_CALCULATION_INTERVAL_IN_MILLIS,
                TimeUnit.MILLISECONDS);
    }
}
