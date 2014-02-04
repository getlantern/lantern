package org.lantern.proxy.pt;

import java.lang.reflect.Constructor;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Factory for {@link PluggableTransport}s.
 */
public class PluggableTransports {
    private static final Map<PtType, Class<? extends PluggableTransport>> TYPES = new ConcurrentHashMap<PtType, Class<? extends PluggableTransport>>();

    static {
        TYPES.put(PtType.FTE, FTE.class);
    }

    public static PluggableTransport newTransport(PtType type,
            Map<String, Object> properties) {
        Class<? extends PluggableTransport> clazz = TYPES.get(type);
        if (clazz == null) {
            throw new RuntimeException(String.format(
                    "Unknown transport type: %1$s", type));
        }
        try {
            Constructor<? extends PluggableTransport> ctor = clazz
                    .getConstructor(Map.class);
            return ctor.newInstance(properties);
        } catch (NoSuchMethodException nsme) {
            throw new RuntimeException(
                    String.format(
                            "Class %1$s must define a single-argument constructor that takes a Map<String, Object> of configuration properties",
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
