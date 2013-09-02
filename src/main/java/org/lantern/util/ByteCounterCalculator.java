package org.lantern.util;

import java.lang.ref.WeakReference;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.lantern.LanternService;

/*
 * <p>Calculates bytesPerSecond for all {@link ByteCounter}s.</p>
 */
public class ByteCounterCalculator implements LanternService {
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
                }, calculationFrequencyInMillis, calculationFrequencyInMillis,
                TimeUnit.MILLISECONDS);
    }

    @Override
    public void stop() {
        executor.shutdownNow();
    }
}
