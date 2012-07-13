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
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;

class LanternFeedback {
    
    public LanternFeedback() {}
    
    public void submit(String message, String replyTo) throws IOException {
        Map <String, String> feedback = new HashMap<String, String>(); 
        feedback.putAll(systemInfo());
        feedback.put("message", message);
        feedback.put("replyto", replyTo == null ? "" : replyTo);
        submitFeedback(feedback);
    }

    protected Map<String, String> systemInfo() {
        final Map<String, String> info = new HashMap<String,String>();

        info.put("lanternVersion", LanternHub.settings().getVersion());        
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
    
    protected void postForm(String url, List<NameValuePair> params) throws IOException {
        final DefaultHttpClient httpclient = new DefaultHttpClient();
        final HttpPost post = new HttpPost(url);
        try {
            UrlEncodedFormEntity entity = new UrlEncodedFormEntity(params, "UTF-8");
            post.setEntity(entity);
            final HttpResponse response = httpclient.execute(post);

            final int statusCode = response.getStatusLine().getStatusCode();
            final HttpEntity responseEntity = response.getEntity();
            // We always have to read the body.
            EntityUtils.consume(responseEntity);
            //responseEntity.consumeContent();
            
            if (statusCode < 200 || statusCode > 299) {
                final Header[] headers = response.getAllHeaders();
                StringBuilder headerVals = new StringBuilder();
                for (int i = 0; i < headers.length; i++) {
                    headerVals.append(headers[i].toString());
                }
                final String err = "Failed to submit feedback. Status was " + statusCode + ", headers " + headerVals.toString();
                throw new IOException(err);
            }
        } catch (IOException e) {
            throw e;
        } catch (final Throwable e) {
            throw new IOException(e);
        } finally {
            httpclient.getConnectionManager().shutdown();
        }
  }
  
  /**
   * quick and dirty google spreadsheet submitter
   */
  private final static String FORM_URL = "https://docs.google.com/a/getlantern.org/spreadsheet/formResponse?formkey=dFl3UEhZV2pNcmFELU5jbTJ6eVhBMmc6MQ&amp;ifq";
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
  protected void submitFeedback(Map<String, String> info) throws IOException {
      final List<NameValuePair> params = new ArrayList<NameValuePair>(info.size());
      for (int i = 0; i < FORM_ORDER.length; i++) {
          final String key = FORM_ORDER[i];
          final String paramName = "entry." + i + ".single"; // what the google form calls it
          params.add(new BasicNameValuePair(paramName,info.get(key)));
      }
      postForm(FORM_URL, params);
  }
}