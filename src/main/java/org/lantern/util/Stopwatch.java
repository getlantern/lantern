package org.lantern.util;


/**
 * Interface for stop watch classes.
 */
public interface Stopwatch {

    /**
     * Starts the stop watch for the current thread. This overwrites any
     * previous start time for the current thread. This is useful, for example,
     * when you start timing something and an exception occurs before you have a
     * chance to stop it. The next time you call start, it's as if the prior
     * call never happened, which is typically what you want when you're trying
     * to get uniform timings.
     * 
     * You can, of course, explicitly call stop in error cases if the above is
     * not what you want.
     */
    void start();

    /**
     * Stops the watch for this thread. This records the number of milliseconds
     * since you last called start and ads that to the total elapsed time in
     * addition to recording the extra call for future calculations of the
     * average time for this stopwatch. This method also updates the max and the
     * min, which are held across all threads.
     */
    void stop();

    /**
     * Stops the watch for this thread. This records the number of milliseconds
     * since you last called start and ads that to the total elapsed time in
     * addition to recording the extra call for future calculations of the
     * average time for this stopwatch. This method also updates the max and the
     * min, which are held across all threads.
     * 
     * @param description A more detailed description of the watch.
     */
    void stop(String description);

    /**
     * Gets the average number of milliseconds between calls to start and stop.
     * 
     * @return The average number of milliseconds between calls to start and
     * stop.
     */
    long getAverage();

    /**
     * Accessor for the maximum elapsed time between calls to start and stop on
     * any single thread. The max applies across all threads.
     * 
     * @return The maximum elapsed time between any call to start and stop on
     * any thread.
     */
    long getMax();

    /**
     * Accessor for the minimum elapsed time between calls to start and stop on
     * any single thread. The max applies across all threads.
     * 
     * @return The minimum elapsed time between any call to start and stop on
     * any thread.
     */
    long getMin();

    /**
     * Prints summary data to the log file.
     */
    void logSummary();


    /**
     * Gets a summary string.
     * 
     * @return A summary string.
     */
    String getSummary();

    /**
     * Accessor for the total elapsed time accumulated for all intervals between
     * start() and stop();
     * 
     * @return The total elapsed time.
     */
    long getTotal();

    /**
     * Accessor for the ID of this stopwatch.
     * 
     * @return The ID of this stopwatch.
     */
    String getId();

    /**
     * Accessor for the name of this stopwatch.
     * 
     * @return The name of this stopwatch.
     */
    String getName();

    /**
     * Accessor for the total number of timing samples this stopwatch has taken.
     * 
     * @return The total number of timing samples.
     */
    int getNumCalls();

    /**
     * Resets the stopwatch. Sets all values back to their initial settings.
     */
    void reset();

    /**
     * Accessor for the description for whatever took the most time.
     * 
     * @return The description for whatever took the most time.
     */
    String getMaxDescription();

    /**
     * Accessor for the description for whatever took the least time.
     * 
     * @return The description for whatever took the least time.
     */
    String getMinDescription();
}
