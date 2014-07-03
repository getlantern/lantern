package org.lantern.util;

public class ProcessUtil {
    /**
     * Gets the current process's PID, or null if it couldn't be gotten. See <a
     * href=
     * "http://stackoverflow.com/questions/35842/how-can-a-java-program-get-its-own-process-id>here</a
     * > for explanation.
     * 
     * @return
     */
    public static Integer getMyPID() {
        try {
            java.lang.management.RuntimeMXBean runtime =
                    java.lang.management.ManagementFactory.getRuntimeMXBean();
            java.lang.reflect.Field jvm = runtime.getClass()
                    .getDeclaredField("jvm");
            jvm.setAccessible(true);
            Object mgmt = jvm.get(runtime);
            java.lang.reflect.Method pid_method =
                    mgmt.getClass().getDeclaredMethod("getProcessId");
            pid_method.setAccessible(true);

            return (Integer) pid_method.invoke(mgmt);
        } catch (Exception e) {
            return null;
        }
    }
}
