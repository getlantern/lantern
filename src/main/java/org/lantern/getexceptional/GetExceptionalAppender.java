package org.lantern.getexceptional;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.commons.httpclient.Header;
import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpException;
import org.apache.commons.httpclient.NameValuePair;
import org.apache.commons.httpclient.methods.PostMethod;
import org.apache.commons.io.FileSystemUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.apache.log4j.AppenderSkeleton;
import org.apache.log4j.Level;
import org.apache.log4j.spi.LocationInfo;
import org.apache.log4j.spi.LoggingEvent;
import org.apache.log4j.spi.ThrowableInformation;

import com.google.common.io.NullOutputStream;

/**
 * Log4J appender that sends data to GetExceptional.
 */
public class GetExceptionalAppender extends AppenderSkeleton {

    private final HttpClient httpClient = new HttpClient();
    
    private final Collection<Bug> recentBugs = 
        Collections.synchronizedSet(new LinkedHashSet<Bug>());
    
    private final ExecutorService pool = Executors.newSingleThreadExecutor();
    
    private final GetExceptionalAppenderCallback callback;

    /**
     * Creates a new appender.
     */
    public GetExceptionalAppender() {
        this(new GetExceptionalAppenderCallback() {
            @Override
            public void addData(final Collection<NameValuePair> dataList) {
            }
        });
    }
    
    /**
     * Creates a new appender with callback.
     * 
     * @param callback The class to call for modificatios prior to submitting
     * the bug.
     */
    public GetExceptionalAppender(final GetExceptionalAppenderCallback callback) {
        this.callback = callback;
    }
    
    @Override
    public void append(final LoggingEvent le) {
        // Only submit the bug under certain conditions.
        if (submitBug(le)) {
            // Just submit it to the thread pool to avoid holding up the calling
            // thread.
            // System.out.println("Submitting bug to pool...");
            this.pool.submit(new BugRunner(le));
        } 
    }

    private boolean submitBug(final LoggingEvent le) {
        // Ignore plain old logs.
        if (!le.getLevel().isGreaterOrEqual(Level.WARN)) {
            return false;
        }

        final LocationInfo li = le.getLocationInformation();
        final Bug lastBug = new Bug(li);
        if (recentBugs.contains(lastBug)) {
            // Don't send duplicates. This should be configurable, but we
            // want to avoid hammering the server.
            return false;
        }
        synchronized (this.recentBugs) {
            // Remove the oldest bug.
            if (this.recentBugs.size() >= 200) {
                final Bug lastIn = this.recentBugs.iterator().next();
                this.recentBugs.remove(lastIn);
            }
            recentBugs.add(lastBug);
            return true;
        }
    }

    @Override
    public void close() {
    }

    @Override
    public boolean requiresLayout() {
        return false;
    }
    

    private final class BugRunner implements Runnable {

        private final LoggingEvent loggingEvent;

        private BugRunner(final LoggingEvent le) {
            this.loggingEvent = le;
        }

        @Override
        public void run() {
            try {
                submitBug(this.loggingEvent);
            } catch (final Throwable t) {
                System.err.println("Error submitting bug: " + t);
            }
        }

        private void submitBug(final LoggingEvent le) {
            System.err.println("Starting to submit bug...");
            final LocationInfo li = le.getLocationInformation();

            final String className = li.getClassName();
            final String methodName = li.getMethodName();
            final int lineNumber;
            final String ln = li.getLineNumber();
            if (NumberUtils.isNumber(ln)) {
                lineNumber = Integer.parseInt(ln);
            } else {
                lineNumber = -1;
            }

            final String threadName = le.getThreadName();

            final String throwableString = getThrowableString(le);

            final String osRoot = SystemUtils.IS_OS_WINDOWS ? "c:" : "/";
            long free = Long.MAX_VALUE;
            try {
                free = FileSystemUtils.freeSpaceKb(osRoot);
                // Convert to megabytes for easy reading.
                free = free / 1024L;
            } catch (final IOException e) {
            }

            final Collection<NameValuePair> dataList = 
                new ArrayList<NameValuePair>();

            dataList.add(new NameValuePair("message", le.getMessage()
                    .toString()));
            dataList.add(new NameValuePair("logLevel", le.getLevel().toString()));
            dataList.add(new NameValuePair("className", className));
            dataList.add(new NameValuePair("methodName", methodName));
            dataList.add(new NameValuePair("lineNumber", String
                    .valueOf(lineNumber)));
            dataList.add(new NameValuePair("threadName", threadName));
            // dataList.add(new NameValuePair("startTime", startTime));
            // dataList.add(new NameValuePair("timeStamp", timestamp));
            dataList.add(new NameValuePair("javaVersion",
                    SystemUtils.JAVA_VERSION));
            dataList.add(new NameValuePair("osName", SystemUtils.OS_NAME));
            dataList.add(new NameValuePair("osArch", SystemUtils.OS_ARCH));
            dataList.add(new NameValuePair("osVersion", SystemUtils.OS_VERSION));
            dataList.add(new NameValuePair("language",
                    SystemUtils.USER_LANGUAGE));
            dataList.add(new NameValuePair("country", SystemUtils.USER_COUNTRY));
            dataList.add(new NameValuePair("timeZone",
                    SystemUtils.USER_TIMEZONE));
            dataList.add(new NameValuePair("userName", SystemUtils.USER_NAME));
            dataList.add(new NameValuePair("throwable", throwableString));
            dataList.add(new NameValuePair("disk_space", String.valueOf(free)));
            dataList.add(new NameValuePair("count", "1"));
            callback.addData(dataList);

            submitData(dataList);
        }

    }
    
    private void submitData(final Collection<NameValuePair> dataList) {
        System.out.println("Submitting data...");

        // TODO: Gotta add the URL here...
        final PostMethod method = new PostMethod();

        final NameValuePair[] data = dataList.toArray(new NameValuePair[0]);
        System.out.println("Sending " + data.length + " fields...");

        method.setRequestBody(data);
        InputStream is = null;
        try {
            System.err.println("Sending data to server...");
            httpClient.executeMethod(method);
            System.err.println("\n\nSent data to server...headers...");

            final int statusCode = method.getStatusCode();
            is = method.getResponseBodyAsStream();
            if (statusCode < 200 || statusCode > 299) {
                final String body = IOUtils.toString(is);
                InputStream bais = null;
                OutputStream fos = null;
                try {
                    bais = new ByteArrayInputStream(body.getBytes());
                    fos = new FileOutputStream(new File("bug_error.html"));
                    IOUtils.copy(bais, fos);
                } finally {
                    IOUtils.closeQuietly(bais);
                    IOUtils.closeQuietly(fos);
                }

                System.err.println("Could not send bug:\n"
                        + method.getStatusLine() + "\n" + body);
                final Header[] headers = method.getResponseHeaders();
                for (int i = 0; i < headers.length; i++) {
                    System.err.println(headers[i]);
                }
                return;
            }

            // We always have to read the body.
            IOUtils.copy(is, new NullOutputStream());
        } catch (final HttpException e) {
            System.err.println("\n\nERROR::HTTP error" + e);
        } catch (final IOException e) {
            System.err.println("\n\nERROR::IO error connecting to server" + e);
        } catch (final Throwable e) {
            System.err.println("Got error\n" + e);
        } finally {
            IOUtils.closeQuietly(is);
            method.releaseConnection();
        }
    }

    private String getThrowableString(final LoggingEvent le) {
        final ThrowableInformation ti = le.getThrowableInformation();
        final String throwableString;
        if (ti != null) {
            final StringBuilder sb = new StringBuilder();
            final String[] throwableStr = ti.getThrowableStrRep();
            for (final String str : throwableStr) {
                sb.append(str);
                sb.append("\n");
            }
            throwableString = sb.toString();
        } else {
            throwableString = "No throwable.";
        }
        return throwableString;
    }


    private static final class Bug {

        private final String className;
        private final String methodName;
        private final String lineNumber;

        private Bug(final LocationInfo li) {
            this.className = li.getClassName();
            this.methodName = li.getMethodName();
            this.lineNumber = li.getLineNumber();
        }

        @Override
        public int hashCode() {
            final int PRIME = 31;
            int result = 1;
            result = PRIME * result
                    + ((className == null) ? 0 : className.hashCode());
            result = PRIME * result
                    + ((lineNumber == null) ? 0 : lineNumber.hashCode());
            result = PRIME * result
                    + ((methodName == null) ? 0 : methodName.hashCode());
            return result;
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj)
                return true;
            if (obj == null)
                return false;
            if (getClass() != obj.getClass())
                return false;
            final Bug other = (Bug) obj;
            if (className == null) {
                if (other.className != null)
                    return false;
            } else if (!className.equals(other.className))
                return false;
            if (lineNumber == null) {
                if (other.lineNumber != null)
                    return false;
            } else if (!lineNumber.equals(other.lineNumber))
                return false;
            if (methodName == null) {
                if (other.methodName != null)
                    return false;
            } else if (!methodName.equals(other.methodName))
                return false;
            return true;
        }
    }

}
