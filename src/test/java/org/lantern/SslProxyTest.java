package org.lantern;

import static org.junit.Assert.*;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.Proxy;
import java.net.URL;
import java.net.URLConnection;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLSocketFactory;

import org.junit.Test;
import org.littleshoot.proxy.KeyStoreManager;

import com.google.api.client.util.Preconditions;


import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport.Builder;

public class SslProxyTest {

    @Test
    public void test() throws Exception {
        final KeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil = 
            new LanternSocketsUtil(null, trustStore);
        final SSLSocketFactory ssl = socketsUtil.newTlsSocketFactoryJavaCipherSuites();
        
        System.setProperty("https.proxyHost", "75.101.134.244");
        System.setProperty("https.proxyPort", "7777");
        URL yahoo = new URL("https://www.google.ca/");
        HttpsURLConnection yc = (HttpsURLConnection) yahoo.openConnection();
        yc.setSSLSocketFactory(ssl);
        System.out.println(yc.getClass().getName());
        BufferedReader in = new BufferedReader(new InputStreamReader(yc.getInputStream()));
        String inputLine;
            while ((inputLine = in.readLine()) != null) {
                System.out.println(inputLine);
                in.close();
            }
        
        // connection with proxy settings
        /*
        System.setProperty("https.proxyHost", "75.101.134.244");
        System.setProperty("https.proxyPort", "7777");
        URL connUrl = new URL("https://www.google.com");
        //final Proxy proxy = 
        URLConnection conn = connUrl.openConnection();//proxy == null ? connUrl.openConnection() : connUrl.openConnection(proxy);
        HttpURLConnection connection = (HttpURLConnection) conn;
        String method = "GET";
        connection.setRequestMethod(method);
      // SSL settings
      if (connection instanceof HttpsURLConnection) {
        HttpsURLConnection secureConnection = (HttpsURLConnection) connection;
        //if (hostnameVerifier != null) {
//          secureConnection.setHostnameVerifier(hostnameVerifier);
//        }
        //if (sslSocketFactory != null) {
          secureConnection.setSSLSocketFactory(ssl);
        //}
      }
      final int code = connection.getResponseCode();
      assertEquals(200, code);
      //return new NetHttpRequest(connection);
       * */
       
    }
}
