package org.mg.common;

import org.apache.commons.lang.ClassUtils;

/**
 * An implementation of the pair interface.
 * 
 * @param <T1> The type of the first element of this pair.
 * @param <T2> The type of the second element of this pair.
 */
public class PairImpl<T1, T2> implements Pair<T1, T2> {
    /**
     * The first object.
     */
    private final T1 first;

    /**
     * The second object.
     */
    private final T2 second;

    /**
     * Constructs a new pair.
     * 
     * @param first The first object.
     * @param second The second object.
     */
    public PairImpl(final T1 first, final T2 second) {
        if (first == null) {
            throw new NullPointerException("Null first arg");
        }
        if (second == null) {
            throw new NullPointerException("Null second arg");
        }
        this.first = first;
        this.second = second;
    }

    public T1 getFirst() {
        return (first);
    }

    public T2 getSecond() {
        return (second);
    }

    @Override
    public boolean equals(final Object other) {
        if (other instanceof Pair) {
            final Pair otherPair = (Pair) other;

            return otherPair.getFirst().equals(first)
                    && otherPair.getSecond().equals(second);
        } else {
            return false;
        }
    }

    @Override
    public int hashCode() {
        final int prime = 203249;
        return (prime * first.hashCode()) + (prime * second.hashCode());
    }

    @Override
    public String toString() {
        final StringBuilder sb = new StringBuilder();
        sb.append(ClassUtils.getShortClassName(getClass()));
        sb.append(" ");
        sb.append(first);
        sb.append(" ");
        sb.append(second);
        return sb.toString();
    }

}
