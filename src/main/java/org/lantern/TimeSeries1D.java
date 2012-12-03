package org.lantern;

import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentNavigableMap;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicLong;


/** 
 * TimeSeries1D tracks a set of observations over time.
 */
public class TimeSeries1D {
    
    protected static final long NO_AGE_LIMIT = -1;
    protected static final long DEFAULT_BUCKET_SIZE = 1;
    private final ConcurrentNavigableMap<Long, AtomicLong> observations;
    private final AtomicLong lifetimeTotal;
    private final long bucketSizeMillis;
    private final long ageLimit;
    
    /** 
     * construct a TimeSeries1D with no bucketing 
     * (bucket size = 1ms) and no age limit
     */
    public TimeSeries1D() {
        this(DEFAULT_BUCKET_SIZE, NO_AGE_LIMIT);
    }
    
    /** 
     * construct a TimeSeries1D with a specific 
     * time bucket size and no age limit. 
     * observations will be clustered into buckets
     * of the given time length.
     *
     * @param bucketSizeMillis - the size in milliseconds of the
     *       time buckets used to cluster observations
     */
    public TimeSeries1D(long bucketSizeMillis) {
        this(bucketSizeMillis, NO_AGE_LIMIT);
    }

    /** 
     * construct a TimeSeries1D with a specific 
     * time bucket size and age limit. Observations
     * will be clustered into buckets of given time length.
     * An observation bucket may be discarded when the difference
     * between the newest entry and the time associated with 
     * the bucket is greater than the ageLimit given.
     * 
     * @param bucketSizeMillis - the size in milliseconds of the
     *        time buckets used to cluster observations
     * 
     * @param ageLimit the maximum difference in age between the
     *        newest and oldest entries.
     * 
     */        
    public TimeSeries1D(long bucketSizeMillis, long ageLimit) {
        this.bucketSizeMillis = bucketSizeMillis;
        this.observations = new ConcurrentSkipListMap<Long,AtomicLong>();
        this.lifetimeTotal = new AtomicLong(0);
        this.ageLimit = ageLimit;
    }
    
    /** 
     * @return the size of the buckets in milliseconds.
     */
    public long getBucketSize() {
        return bucketSizeMillis;
    }
    
    /** 
     * add an observation at the current timestamp.
     * this value is _added_ to any other observations
     * in the time bucket that covers the current time.
     * 
     * @param value the value at the current time
     */ 
    public void addData(long value) {
        addData(System.currentTimeMillis(), value);
    }
    
    /**
     * add an observation at a specific timestamp.
     * this value is _added_ to any other observations
     * in the time bucket that covers the given timestamp
     * 
     * @param timestamp the timestamp for the observation
     * @param value the value at the given timestamp
     */
    public void addData(long timestamp, long value) {
        lifetimeTotal.addAndGet(value);
        final long bucketKey = bucketForTimestamp(timestamp);
        if (!observations.containsKey(bucketKey)) {
            observations.putIfAbsent(bucketKey, new AtomicLong(0));
        }
        final AtomicLong bucket = observations.get(bucketKey);        
        // may have been concurrently cleaned up for being too old...
        if (bucket == null) {
            return;
        }
        
        bucket.addAndGet(value);
        checkLimits();
        // could certainly update other statistics here.
    }

    public long latestValue() {
        Map.Entry<Long, AtomicLong> last = observations.lastEntry(); 
        if (last != null) {
            return last.getValue().get();
        }
        else {
            return 0;
        }
    }

    /** 
     * computes the average *per bucket* value in the set of 
     * buckets that cover the time window given.
     * 
     * @param windowMin minimum time in the window
     * @param windowMax maximum time in the window
     *
     * @return the average per-bucket value in the
     * time window given.
     */
    public double windowAverage(long minTimestamp, long maxTimestamp) {
        long minBucket = bucketForTimestamp(minTimestamp);
        long maxBucket = bucketForTimestamp(maxTimestamp);
        
        long buckets = (maxBucket - minBucket) + 1;
        long total = 0;
        
        for (AtomicLong cur :
             observations.subMap(minBucket, true, maxBucket, true).values()) {
            total += cur.get(); 
        }
        
        return total / (double) buckets;
    }
    
    /** 
     * computes the total value in the set of
     * buckets that cover the time window given.
     * 
     * @param windowMin minimum time in the window
     * @param windowMax maximum time in the window
     *
     * @return the total of all buckets covering the
     * time window given.
     */
    public double windowTotal(long minTimestamp, long maxTimestamp) {
        long minBucket = bucketForTimestamp(minTimestamp);
        long maxBucket = bucketForTimestamp(maxTimestamp);
        
        long total = 0;
        for (AtomicLong cur :
             observations.subMap(minBucket, true, maxBucket, true).values()) {
            total += cur.get(); 
        }
        
        return total;
    }
    
    /** 
     * returns the total of all observations seen by this
     * time series (including those outside the current set)
     */
    public long lifetimeTotal() {
        return lifetimeTotal.get();
    }
    
    /**
     * resets the lifetime total of all observations to 0
     */
    public void resetLifetimeTotal() {
        resetLifetimeTotal(0);
    }
    
    /**
     * resets the lifetime total of all observations to the
     * given value.
     */
    public void resetLifetimeTotal(long value) {
        lifetimeTotal.set(value);
    }
    
    // reset values 
    public void reset() {
        observations.clear();
        resetLifetimeTotal();
    }
    
    // ...

    protected long bucketForTimestamp(final long timestamp) {
        return timestamp / bucketSizeMillis;
    }
    
    protected void checkLimits() {
        if (ageLimit == NO_AGE_LIMIT) {
            return;
        }
        
        long newestKey = observations.lastKey();
        long minKey = bucketForTimestamp((newestKey*bucketSizeMillis) - ageLimit);
        
        List<Long> deleteKeys = new LinkedList<Long>();
        for (long i : observations.headMap(minKey).keySet()) {
            deleteKeys.add(i);
        }
        for (long key : deleteKeys) {
            observations.remove(key);
        }
    }

}