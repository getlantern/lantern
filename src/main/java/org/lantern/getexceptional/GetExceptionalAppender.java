package org.lantern.getexceptional;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.commons.httpclient.Header;
import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpException;
import org.apache.commons.httpclient.methods.PostMethod;
import org.apache.commons.httpclient.methods.RequestEntity;
import org.apache.commons.httpclient.methods.StringRequestEntity;
import org.apache.commons.io.FileSystemUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.apache.log4j.AppenderSkeleton;
import org.apache.log4j.Level;
import org.apache.log4j.spi.LocationInfo;
import org.apache.log4j.spi.LoggingEvent;
import org.apache.log4j.spi.ThrowableInformation;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.littleshoot.util.DateUtils;

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

    private final boolean threaded;

    private final String apiKey;

    /**
     * Creates a new appender.
     */
    public GetExceptionalAppender(final String apiKey) {
        this(apiKey, new GetExceptionalAppenderCallback() {
            @Override
            public void addData(final JSONObject json) {
            }
        }, true);
    }
    
    /**
     * Creates a new appender with callback.
     * 
     * @param callback The class to call for modifications prior to submitting
     * the bug.
     */
    public GetExceptionalAppender(final String apiKey, 
        final GetExceptionalAppenderCallback callback) {
        this(apiKey, callback, true);
    }
    
    /**
     * Creates a new appender with a flag for whether or not to thread 
     * submissions. Not threading can be useful for testing in particular.
     * 
     * @param threaded Whether or not to thread submissions to GetExceptional.
     */
    public GetExceptionalAppender(final String apiKey, final boolean threaded) {
        this(apiKey, new GetExceptionalAppenderCallback() {
            @Override
            public void addData(final JSONObject json) {
            }
        }, threaded);
    }
    
    /**
     * Creates a new appender with callback.
     * 
     * @param callback The class to call for modificatios prior to submitting
     * the bug.
     */
    public GetExceptionalAppender(final String apiKey, 
        final GetExceptionalAppenderCallback callback,
        final boolean threaded) {
        this.apiKey = apiKey;
        this.callback = callback;
        this.threaded = threaded;
    }

    @Override
    public void append(final LoggingEvent le) {
        // Only submit the bug under certain conditions.
        if (submitBug(le)) {
            // Just submit it to the thread pool to avoid holding up the calling
            // thread.
            if (threaded) {
                this.pool.submit(new BugRunner(le));
            } else {
                new BugRunner(le).run();
            }
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

            final JSONObject json = new JSONObject();
            json.put("request", requestData(le));
            json.put("application_environment", appData(le));
            json.put("exception", exceptionData(le));
            json.put("client", clientData(le));
            final String jsonStr = json.toJSONString();
            System.out.println("JSON:\n"+jsonStr);
            submitData(jsonStr);
        }
    }
    
    private void submitData(final String requestBody) {
        System.out.println("Submitting data...");

        final PostMethod method = 
            new PostMethod("http://api.getexceptional.com/api/errors?" +
                "api_key="+this.apiKey+"&protocol_version=6");

        final RequestEntity re;
        try {
            re = new StringRequestEntity(requestBody, "application/json", "UTF-8");
        } catch (final UnsupportedEncodingException e) {
            System.err.println("Bad encoding - should never happen: "+e);
            return;
        }
        method.setRequestEntity(re);
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

    private JSONObject requestData(final LoggingEvent le) {
        final JSONObject json = new JSONObject();
        return json;
    }
    
    private JSONObject appData(final LoggingEvent le) {
        final JSONObject json = new JSONObject();
        json.put("application_root_directory", "/");
        json.put("env", getEnv(le));
        return json;
    }
    private JSONObject getEnv(final LoggingEvent le) {
        final JSONObject json = new JSONObject();
        final LocationInfo li = le.getLocationInformation();
        final int lineNumber;
        final String ln = li.getLineNumber();
        if (NumberUtils.isNumber(ln)) {
            lineNumber = Integer.parseInt(ln);
        } else {
            lineNumber = -1;
        }
        json.put("message", le.getMessage().toString());
        json.put("logLevel", le.getLevel().toString());
        json.put("methodName", li.getMethodName());
        json.put("lineNumber", lineNumber);
        json.put("threadName", le.getThreadName());
        json.put("javaVersion", SystemUtils.JAVA_VERSION);
        json.put("osName", SystemUtils.OS_NAME);
        json.put("osArch", SystemUtils.OS_ARCH);
        json.put("osVersion", SystemUtils.OS_VERSION);
        json.put("language", SystemUtils.USER_LANGUAGE);
        json.put("country", SystemUtils.USER_COUNTRY);
        json.put("timeZone", SystemUtils.USER_TIMEZONE);
        json.put("userName", SystemUtils.USER_NAME);
        
        final String osRoot = SystemUtils.IS_OS_WINDOWS ? "c:" : "/";
        long free = Long.MAX_VALUE;
        try {
            free = FileSystemUtils.freeSpaceKb(osRoot);
            // Convert to megabytes for easy reading.
            free = free / 1024L;
        } catch (final IOException e) {
        }
        json.put("disk_space", String.valueOf(free));
        
        this.callback.addData(json);
        return json;
    }
    
    private JSONObject exceptionData(final LoggingEvent le) {
        final JSONObject json = new JSONObject();
        json.put("message", le.getMessage().toString());
        json.put("backtrace", getThrowableArray(le));
        final LocationInfo li = le.getLocationInformation();
        final String exceptionClass;
        if (li == null) {
            exceptionClass = "unknown";
        } else {
            exceptionClass = li.getClassName();
        }
        json.put("exception_class", exceptionClass);
        json.put("occurred_at", DateUtils.iso8601());
        return json;
    }
    
    private JSONObject clientData(final LoggingEvent le) {
        final JSONObject json = new JSONObject();
        json.put("client", "getexceptional-java-plugin");
        json.put("version", "0.1");
        json.put("protocol_version", "6");
        return json;
    }
    
    private JSONArray getThrowableArray(final LoggingEvent le) {
        final JSONArray array = new JSONArray();
        final ThrowableInformation ti = le.getThrowableInformation();
        if (ti != null) {
            final StringBuilder sb = new StringBuilder();
            final String[] throwableStr = ti.getThrowableStrRep();
            for (final String str : throwableStr) {
                array.add(str.trim());
            }
        } 
        return array;
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
