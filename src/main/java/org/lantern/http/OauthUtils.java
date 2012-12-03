package org.lantern.http;

import java.io.IOException;
import java.io.InputStream;

import org.apache.commons.io.IOUtils;

import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.json.jackson.JacksonFactory;

public class OauthUtils {

    public static final String REDIRECT_URL =
        "http://localhost:7777/oauth2callback";
    
    
    public static GoogleClientSecrets loadClientSecrets() throws IOException {
        InputStream is = null;
        try {
            is = OauthUtils.class.getResourceAsStream(
                "client_secrets_installed.json");
            final GoogleClientSecrets secrets =
                GoogleClientSecrets.load(new JacksonFactory(), is);
            //log.debug("Secrets: {}", secrets);
            return secrets;
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
}
