package org.lantern.util;

import java.util.Collection;
import java.util.Map;
import java.util.Set;
import java.util.SortedSet;
import java.util.Map.Entry;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class that manages all stopwatches. Use this to create stopwatches, to print
 * summaries of their data, etc.
 */
public class StopwatchManager {

    private static final Logger LOG = 
        LoggerFactory.getLogger(StopwatchManager.class);
    private static final ConcurrentHashMap<String, Map<String, Stopwatch>> watches = 
        new ConcurrentHashMap<String, Map<String, Stopwatch>>();


    /**
     * Gets a new {@link Stopwatch}. If a {@link Stopwatch} already exists for
     * the specified ID, it returns that one.
     * 
     * @param id The unique ID for the {@link Stopwatch} desired.
     * @param loggerName The name of the logger to tell the stopwatch to use.
     * @param watchGroup The ID for the group the watch is associated with.
     * Watches in the same group can be compared to each other to determine, 
     * for example, the percentage of the whole group's time each watch 
     * consumes.
     * @return The {@link Stopwatch}.
     */
    public static Stopwatch getStopwatch(final String id,
        final String loggerName, final String watchGroup) {
        return getStopwatch(id, id, loggerName, watchGroup);
    }


    /**
     * Gets a new {@link Stopwatch}. If a {@link Stopwatch} already exists for
     * the specified ID, it returns that one.
     * 
     * @param id The unique ID for the {@link Stopwatch} desired.
     * @param name The display name for the stopwatch.
     * @param loggerName The name of the logger to tell the stopwatch to use.
     * @param watchGroup The ID for the group the watch is associated with.
     * Watches in the same group can be compared to each other to determine,
     * for example, the percentage of the whole group's time each watch
     * consumes.
     * @return The {@link Stopwatch}.
     */
    public static Stopwatch getStopwatch(final String id, final String name,
        final String loggerName, final String watchGroup) {
        final Stopwatch watch = new DefaultStopwatch(name, id, loggerName);
        final Map<String, Stopwatch> map = new ConcurrentHashMap<String, Stopwatch>();
        final Map<String, Stopwatch> existing = watches.putIfAbsent(watchGroup,
            map);
        if (existing != null) {
            if (existing.containsKey(id)) {
                LOG.info("Returning existing stopwatch");
                return existing.get(id);
            }
            existing.put(id, watch);
        } else {
            map.put(id, watch);
        }
        return watch;
    }

    /**
     * Prints a summary of all timed data, including percentages of total time
     * each individual timer consumes.
     * 
     * @param logId The ID of the logger to use.
     */
    public static void logSummaries(final String logId) {
        final Logger logger = LoggerFactory.getLogger(logId);
        final Set<Entry<String, Map<String, Stopwatch>>> allWatches =
                watches.entrySet();
        for (final Entry<String, Map<String, Stopwatch>> entry : allWatches) {
            final String groupName = entry.getKey();
            logger.debug("Printing stop watches for group: " + groupName);
            final Collection<Stopwatch> stops = entry.getValue().values();
            long totalAll = 0L;
            for (final Stopwatch sw : stops) {
                totalAll += sw.getTotal();
            }
            logger.debug("Total timed calls: " + totalAll);
            
            final SortedSet<Stopwatch> sorted = new TreeSet<Stopwatch>();
            for (final Stopwatch sw : stops) {
                sorted.add(sw);
            }
            
            for (final Stopwatch sw : sorted) {
                final long total = sw.getTotal();
                //final int calls = sw.getNumCalls();
                // final String id = sw.getId();
                final String name = sw.getName();
                final double rawPercent = (double) total / (double) totalAll;
                final long percent = Math.round(rawPercent * 100);
                logger.debug(groupName + ": " + name + " is "
                        + percent + "% of total with " + total + " out of "
                        + totalAll +" total milliseconds");
            }
        }
    }

    /**
     * Resets all stopwatches.
     */
    public static void reset() {
        final Set<Entry<String, Map<String, Stopwatch>>> allWatches = 
                watches.entrySet();
        for (final Entry<String, Map<String, Stopwatch>> entry : allWatches) {
            final Collection<Stopwatch> stops = entry.getValue().values();
            for (final Stopwatch sw : stops) {
                sw.reset();
            }
        }
    }
}
