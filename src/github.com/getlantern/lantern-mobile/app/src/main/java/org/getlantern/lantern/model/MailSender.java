package org.getlantern.lantern.model;

import com.microtripit.mandrillapp.lutung.MandrillApi;
import com.microtripit.mandrillapp.lutung.view.MandrillMessage;;
import com.microtripit.mandrillapp.lutung.view.MandrillMessageStatus;

import java.util.ArrayList;
import java.util.HashMap;

import android.util.Log;

public class MailSender {   

    private static final String TAG = "MailSender";
    private final String apiKey = "fmYlUdjEpGGonI4NDx9xeA";

    public synchronized void sendMail(String toEmail) throws Exception {   
        MandrillApi mandrillApi = new MandrillApi(apiKey);
        MandrillMessage message = new MandrillMessage();

        ArrayList<MandrillMessage.Recipient> recipients = new ArrayList<MandrillMessage.Recipient>();
        MandrillMessage.Recipient recipient = new MandrillMessage.Recipient();
        recipient.setEmail(toEmail);
        recipients.add(recipient);

        message.setTo(recipients);
        message.setPreserveRecipients(true);

        final HashMap<String,String> templateContent =
            new HashMap<String,String>();
        templateContent.put("content", "example content");
        mandrillApi.messages().sendTemplate("download-link-from-lantern-website",
                templateContent, message, null);
    }   
}  
