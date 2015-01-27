package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;
import io.netty.handler.codec.http.HttpHeaders;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.Callable;
import java.util.zip.GZIPOutputStream;

import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpHead;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.lantern.proxy.pt.Flashlight;
import org.lantern.util.DefaultHttpClientFactory;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class HttpClientFactoryTest {

    private Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void testFallbackProxyConnection() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //System.setProperty("javax.net.debug", "ssl");
        
        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
           @Override
            public Void call() throws Exception {
               final HttpClientFactory factory = 
                       new DefaultHttpClientFactory(new AllCensored());
               
               // Because we are censored, this should use the local proxy
               final HttpClient httpClient = factory.newClient();
               TestingUtils.assertIsUsingGetModeProxy(httpClient);
               
               httpClient.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 10000);
               httpClient.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 8000);

               final HttpHead head = new HttpHead("https://www.google.com");
               head.setHeader(Flashlight.X_FLASHLIGHT_QOS, Integer.toString(Flashlight.HIGH_QOS));
               
               log.debug("About to execute get!");
               final HttpResponse response = httpClient.execute(head);
               final StatusLine line = response.getStatusLine();
               final int code = line.getStatusCode();
               if (code < 200 || code > 299) {
                   //log.error("Head request failed?\n"+line);
                   fail("Could not proxy");
               }
               head.reset();
                return null;
            } 
        });
    }    
}
