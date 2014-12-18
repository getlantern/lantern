package org.lantern.util;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ProcessUtil {
    /**
     * Gets the current process's PID, or null if it couldn't be gotten. See <a
     * href=
     * "http://stackoverflow.com/questions/35842/how-can-a-java-program-get-its-own-process-id>here</a
     * > for explanation.
     * 
     * @return The process ID for this application.
     * @throws IOException If we could not determine the process ID.
     */
    public static int getMyPID() throws IOException {
        
        final RuntimeMXBean runtime = ManagementFactory.getRuntimeMXBean();
        final String processName = runtime.getName();
        try {
            return extractPid(processName);
        } catch (IOException e) {
            try {
                final Field jvm = runtime.getClass().getDeclaredField("jvm");
                jvm.setAccessible(true);
                final Object mgmt = jvm.get(runtime);
                final Method pid_method = 
                        mgmt.getClass().getDeclaredMethod("getProcessId");
                pid_method.setAccessible(true);
                return (Integer) pid_method.invoke(mgmt);
            } catch (Exception exc) {
                throw new IOException("Still could not determine the process "
                        + "ID for process name: "+processName, e);
            }
        }
    }
    
    /**
     * Extracts the process ID from the process name. The name should be always
     * available on all platforms and is a public method/supported API.
     */
    private static int extractPid(final String processName) throws IOException {
        // Modified from http://www.golesny.de/p/code/javagetpid
        // tested on: 
        // - windows xp sp 2, java 1.5.0_13 */
        // - mac os x 10.4.10, java 1.5.0 */
        // - debian linux, java 1.5.0_13 */
        // all return pid@host, e.g 2204@antonius */
            
        final Pattern pattern = 
                Pattern.compile("^([0-9]+)@.+$", Pattern.CASE_INSENSITIVE);
        final Matcher matcher = pattern.matcher(processName);
        if (matcher.matches()) {
            return Integer.parseInt(matcher.group(1));
        }
        throw new IOException("Could not parse from process name: "+processName);
     }
}
