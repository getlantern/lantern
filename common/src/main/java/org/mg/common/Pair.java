package org.mg.common;

/**
 * A pair of objects. It is often useful to represent pairs of objects. This
 * interface provides a type-safe and reusable way of doing so.
 * 
 * @param <T1> The type of the first element of this pair.
 * @param <T2> The type of the second element of this pair.
 */
public interface Pair<T1,T2>
    {
    /**
     * Returns the first object in the pair.
     *      
     * @return The first object in the pair.
     */
    T1 getFirst ();

    /**
     * Returns the second object in the pair.
     *
     * @return The second object in the pair.
     */
    T2 getSecond ();
    }