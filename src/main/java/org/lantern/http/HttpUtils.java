package org.lantern.http;

import java.io.IOException;
import java.util.Enumeration;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.Map.Entry;

import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.httpclient.HttpStatus;
import org.slf4j.LoggerFactory;
import org.slf4j.Logger;

public class HttpUtils {

    private static final Logger LOG = LoggerFactory.getLogger(HttpUtils.class);
    
    private HttpUtils() {}
    
    public static void sendClientError(final HttpServletResponse resp, 
        final String msg) {
        sendError(resp, HttpStatus.SC_BAD_REQUEST, msg);
    }
    
    public static void sendServerError(final HttpServletResponse resp, 
        final String msg) {
        sendError(resp, HttpStatus.SC_INTERNAL_SERVER_ERROR, msg);
    }
    
    public static void sendServerError(final Exception e, 
        final HttpServletResponse resp, final boolean sendErrors) {
        LOG.info("Caught exception", e);
        if (sendErrors) {
            sendError(resp, HttpStatus.SC_INTERNAL_SERVER_ERROR, e.getMessage());
        }
    }

    public static void sendError(final HttpServletResponse resp, final int errorCode, 
        final String msg) {
        try {
            resp.sendError(errorCode, msg);
        } catch (final IOException e) {
            LOG.info("Could not send response", e);
        }
    }
    

    /**
     * Converts the request arguments to a map of parameter keys to single
     * values, ignoring multiple values.
     * 
     * @param req The request.
     * @return The mapped argument names and values.
     */
    public static Map<String, String> toParamMap(final ServletRequest req) {
        final Map<String, String> map = new TreeMap<String, String>(
                String.CASE_INSENSITIVE_ORDER);
        final Map<String, String[]> paramMap = req.getParameterMap();
        final Set<Entry<String, String[]>> entries = paramMap.entrySet();
        for (final Entry<String, String[]> entry : entries) {
            final String[] values = entry.getValue();
            map.put(entry.getKey(), values[0]);
        }
        return map;
    }
    
    
    /**
     * Prints request headers.
     * 
     * @param request The request.
     */
    public static void printRequestHeaders(final HttpServletRequest request) {
        LOG.debug(getRequestHeaders(request).toString());
    }

    /**
     * Gets request headers as a string.
     * 
     * @param request The request.
     * @return The request headers as a string.
     */
    public static String getRequestHeaders(final HttpServletRequest request) {
        final Enumeration<String> headers = request.getHeaderNames();
        final StringBuilder sb = new StringBuilder();
        sb.append("\n");
        while (headers.hasMoreElements()) {
            final String headerName = headers.nextElement();
            sb.append(headerName);
            sb.append(": ");
            sb.append(request.getHeader(headerName));
            sb.append("\n");
        }
        return sb.toString();
    }
    

    /**
     * Creates a map of header names to values from an HTTP request.
     * 
     * @param request The HTTP request.
     * @return The map of header names to values.
     */
    public static Map<String, String> toHeaderMap(
            final HttpServletRequest request) {
        final Map<String, String> map = new TreeMap<String, String>(
                String.CASE_INSENSITIVE_ORDER);
        final Enumeration<String> headers = request.getHeaderNames();
        while (headers.hasMoreElements()) {
            final String name = headers.nextElement();
            final String value = request.getHeader(name);
            map.put(name, value);
        }
        return map;
    }
    
}
