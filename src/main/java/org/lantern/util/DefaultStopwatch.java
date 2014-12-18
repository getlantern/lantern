package org.lantern.util;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utility class for timing calls.
 */
class DefaultStopwatch implements Stopwatch, Comparable<DefaultStopwatch> {

    private final Logger logger;

    private final AtomicInteger numCalls = new AtomicInteger(0);

    private volatile long total;

    private volatile long minTime = Long.MAX_VALUE;

    private volatile long maxTime;

    private volatile String maxDescription;

    private volatile String minDescription;

    private final String id;

    private final Map<String, Long> startTimes = 
            new ConcurrentHashMap<String, Long>();

    private final String name;

    DefaultStopwatch(final String loggerName) {
        this(String.valueOf(RandomUtils.nextInt()), loggerName);
    }

    DefaultStopwatch(final String id, final String loggerName) {
        this(id, id, loggerName);
    }

    DefaultStopwatch(final String name, final String id, final String loggerName) {
        this.name = name;
        this.id = id;
        logger = LoggerFactory.getLogger(loggerName);
    }

    @Override
    public void reset() {
        startTimes.clear();
        total = 0L;
        minTime = Long.MAX_VALUE;
        maxTime = 0L;
        maxDescription = "";
        minDescription = "";
    }

    @Override
    public void start() {
        final String threadName = Thread.currentThread().getName();
        startTimes.put(threadName, System.currentTimeMillis());
    }

    @Override
    public void stop() {
        stop(StringUtils.EMPTY);
    }

    @Override
    public void stop(final String description) {
        final long lastStopTime = System.currentTimeMillis();
        final String threadName = Thread.currentThread().getName();
        if (!startTimes.containsKey(threadName)) {
            return;
        }
        final long lastStartTime = startTimes.get(threadName);
        final long lastTime = lastStopTime - lastStartTime;
        numCalls.incrementAndGet();
        total += lastTime;
        if (lastTime < minTime) {
            minTime = lastTime;
            minDescription = description;
        }

        if (lastTime > maxTime) {
            maxTime = lastTime;
            maxDescription = description;
        }
    }

    @Override
    public int getNumCalls() {
        return numCalls.get();
    }

    @Override
    public long getAverage() {
        if (numCalls.get() == 0)
            return 0L;
        return total / numCalls.get();
    }

    @Override
    public long getMax() {
        return maxTime;
    }

    @Override
    public long getMin() {
        if (minTime == Long.MAX_VALUE)
            return 0L;
        return minTime;
    }

    @Override
    public long getTotal() {
        return total;
    }

    @Override
    public String getId() {
        return this.id;
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public void logSummary() {
        logger.info(getSummary());
    }

    @Override
    public String getMaxDescription() {
        return maxDescription;
    }

    @Override
    public String getMinDescription() {
        return minDescription;
    }

    @Override
    public String getSummary() {
        final StringBuilder sb = new StringBuilder();
        sb.append(this.name);
        sb.append(": average: ");
        sb.append(getAverage());
        sb.append(" max: ");
        sb.append(getMax());
        sb.append(" min: ");
        sb.append(getMin());
        sb.append(" total: ");
        sb.append(total);
        sb.append(" for ");
        sb.append(numCalls);
        sb.append(" calls");
        return sb.toString();
    }

    @Override
    public int compareTo(final DefaultStopwatch ds) {
        return Long.valueOf(ds.getTotal()).compareTo(Long.valueOf(total));
    }
}
