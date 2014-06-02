package org.lantern.proxy.pt;

import java.lang.reflect.Constructor;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Factory for {@link PluggableTransport}s.
 */
public class PluggableTransports {
    private static final Map<PtType, Class<? extends PluggableTransport>> TYPES = new ConcurrentHashMap<PtType, Class<? extends PluggableTransport>>();

    static {
        TYPES.put(PtType.FTE, FTE.class);
        TYPES.put(PtType.FLASHLIGHT, Flashlight.class);
    }

    public static PluggableTransport newTransport(PtType type,
            Properties props) {
        Class<? extends PluggableTransport> clazz = TYPES.get(type);
        if (clazz == null) {
            throw new RuntimeException(String.format(
                    "Unknown transport type: %1$s", type));
        }
        try {
            Constructor<? extends PluggableTransport> ctor =
                    clazz.getConstructor(Properties.class);
            return ctor.newInstance(props);
        } catch (NoSuchMethodException nsme) {
            throw new RuntimeException(
                    String.format(
                            "Class %1$s must define a single-argument constructor that takes a Properties object with configuration parameters",
                            clazz.getName()));
        } catch (Throwable t) {
            Throwable cause = t.getCause();
            if (cause instanceof RuntimeException) {
                throw (RuntimeException) cause;
            } else {
                throw new RuntimeException(cause);
            }
        }
    }
}
