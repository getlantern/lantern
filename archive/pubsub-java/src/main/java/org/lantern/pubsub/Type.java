package org.lantern.pubsub;

/**
 * Enumerates types of {@link Message}.
 */
public class Type {
    public static final byte KeepAlive = 0;
    public static final byte Authenticate = 1;
    public static final byte Subscribe = 2;
    public static final byte Unsubscribe = 3;
    public static final byte Publish = 4;
}
