package org.lantern;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.io.FileSystemUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.lantern.util.LanternHttpClient;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternFeedback {
    
    private final LanternHttpClient httpClient;
    private final boolean testing;

    @Inject
    public LanternFeedback(final LanternHttpClient httpClient) {
        this(httpClient, false);
    }
    
    public LanternFeedback(final LanternHttpClient httpClient, 
        final boolean testing) {
        this.httpClient = httpClient;
        this.testing = testing;
    }

    public int submit(String message, String replyTo) throws IOException {
        final Map <String, String> feedback = new HashMap<String, String>(); 
        feedback.putAll(systemInfo());
        feedback.put("message", message);
        feedback.put("replyto", replyTo == null ? "" : replyTo);
        return submitFeedback(feedback);
    }

    protected Map<String, String> systemInfo() {
        final Map<String, String> info = new HashMap<String,String>();

        info.put("lanternVersion", LanternClientConstants.VERSION);        
        info.put("javaVersion", SystemUtils.JAVA_VERSION);
        info.put("osName", SystemUtils.OS_NAME);
        info.put("osArch", SystemUtils.OS_ARCH);
        info.put("osVersion", SystemUtils.OS_VERSION);
        info.put("language", SystemUtils.USER_LANGUAGE);
        info.put("country", SystemUtils.USER_COUNTRY);
        info.put("timeZone", SystemUtils.USER_TIMEZONE);
        
        final String osRoot = SystemUtils.IS_OS_WINDOWS ? "c:" : "/";
        long free = Long.MAX_VALUE;
        try {
            free = FileSystemUtils.freeSpaceKb(osRoot);
            // Convert to megabytes for easy reading.
            free = free / 1024L;
        } catch (final IOException e) {
        }
        info.put("diskSpace", String.valueOf(free));
        return info;
    }
    
    private int postForm(final String url, final List<NameValuePair> params) 
            throws IOException {
        // If we're testing we just make sure we can connect successfully.
        final HttpPost post;
        if (testing) {
            post = new HttpPost(HOST);
        } else {
            post = new HttpPost(url);
        }
        try {
            // Don't set the form if we're just testing. This will enable us
            // to test the connection but not the actual submission of the 
            // form.
            if (!testing) {
                final UrlEncodedFormEntity entity = 
                    new UrlEncodedFormEntity(params, "UTF-8");
                post.setEntity(entity);
            }
            final HttpResponse response = httpClient.execute(post);

            final int statusCode = response.getStatusLine().getStatusCode();
            final HttpEntity responseEntity = response.getEntity();
            // We always have to read the body.
            EntityUtils.consume(responseEntity);
            //responseEntity.consumeContent();
            
            if (statusCode < 200 || statusCode > 299) {
                final Header[] headers = response.getAllHeaders();
                final StringBuilder headerVals = new StringBuilder();
                for (int i = 0; i < headers.length; i++) {
                    headerVals.append(headers[i].toString());
                    headerVals.append("\n");
                }
                final String err = "Failed to submit feedback. Status was " + 
                        statusCode + ", headers " + headerVals.toString();
                throw new IOException(err);
            }
            return statusCode;
        } finally {
            post.reset();
        }
    }
  
    private final static String HOST = "https://docs.google.com";
    /**
     * quick and dirty google spreadsheet submitter
     */
    private final static String FORM_URL = 
        HOST+"/a/getlantern.org/spreadsheet/formResponse?formkey=dFl3UEhZV2pNcmFELU5jbTJ6eVhBMmc6MQ&amp;ifq";
    private final String [] FORM_ORDER = {
        "message",
        "replyto",
        "javaVersion",
        "osName",
        "osArch",
        "osVersion",
        "language",
        "country",
        "timeZone",
        "diskSpace",
        "lanternVersion"
    };
    
    private int submitFeedback(final Map<String, String> info) throws IOException {
        final List<NameValuePair> params = new ArrayList<NameValuePair>(info.size());
        for (int i = 0; i < FORM_ORDER.length; i++) {
            final String key = FORM_ORDER[i];
            final String paramName = "entry." + i + ".single"; // what the google form calls it
            params.add(new BasicNameValuePair(paramName,info.get(key)));
        }
        return postForm(FORM_URL, params);
    }
}