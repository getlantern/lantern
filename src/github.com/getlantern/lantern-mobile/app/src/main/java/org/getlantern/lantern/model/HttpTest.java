package org.getlantern.lantern.model;

import java.net.HttpURLConnection;
import java.net.URL;
import java.io.DataOutputStream;
import java.io.InputStream;
import java.io.BufferedReader;
import java.io.InputStreamReader;


/**
 * Created by todd on 8/12/15.
 */
public class HttpTest {
    public static String runTest(String targetURL, String urlParameters) {
        HttpURLConnection connection = null;
        try {

            System.setProperty("http.proxyHost", "127.0.0.1");
            System.setProperty("http.proxyPort", "9121");
            System.setProperty("https.proxyHost", "127.0.0.1");
            System.setProperty("https.proxyPort", "9121");

            //Create connection
            URL url = new URL(targetURL);
            connection = (HttpURLConnection)url.openConnection();
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Content-Type",
                    "application/x-www-form-urlencoded");

            connection.setRequestProperty("Content-Length",
                    Integer.toString(urlParameters.getBytes().length));
            connection.setRequestProperty("Content-Language", "en-US");

            connection.setUseCaches(false);
            connection.setDoOutput(true);

            //Send request
            DataOutputStream wr = new DataOutputStream (
                    connection.getOutputStream());
            wr.writeBytes(urlParameters);
            wr.close();

            //Get Response
            /*InputStream is = connection.getInputStream();
              BufferedReader rd = new BufferedReader(new InputStreamReader(is));
              StringBuilder response = new StringBuilder(); // or StringBuffer if not Java 5+
              String line;
              while((line = rd.readLine()) != null) {
              response.append(line);
              response.append('\r');
              }
              rd.close();
              return response.toString();*/
            return "";
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        } finally {
            if(connection != null) {
                connection.disconnect();
            }
        }
    }
}
