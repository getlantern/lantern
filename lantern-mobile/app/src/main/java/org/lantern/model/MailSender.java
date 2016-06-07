package org.lantern.model;

import com.microtripit.mandrillapp.lutung.MandrillApi;
import com.microtripit.mandrillapp.lutung.view.MandrillMessage;
import com.microtripit.mandrillapp.lutung.view.MandrillMessageStatus;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import android.util.Log;


public class MailSender {   

    private static final String TAG = "MailSender";
    private final String apiKey = "fmYlUdjEpGGonI4NDx9xeA";

    public synchronized void sendLogs(String logsFile) {

        try {

            Log.d(TAG, "Send logs clicked; log directory: " + logsFile);

            byte[] bytes = org.apache.commons.io.FileUtils.readFileToByteArray(new File(logsFile));

            List<MandrillMessage.MessageContent> attachments = new ArrayList<MandrillMessage.MessageContent>();

            MandrillMessage.MessageContent logContent = new MandrillMessage.MessageContent();
            logContent.setType("text/plain");
            logContent.setName("lantern.log");
            org.apache.commons.codec.binary.Base64 base64 = new org.apache.commons.codec.binary.Base64();
            String encoded = new String(base64.encode(bytes));
            logContent.setContent(encoded);

            attachments.add(logContent);

            sendMail("team@getlantern.org", attachments);
        } catch (Exception e) {
            Log.e(TAG, "Error sending log messages: " + e.getMessage());
        }
    }

    public synchronized void sendMail(String toEmail) throws Exception {                          
        sendMail(toEmail, null);
    }

    public synchronized void sendMail(String toEmail, List<MandrillMessage.MessageContent> attachments) throws Exception {

        MandrillApi mandrillApi = new MandrillApi(apiKey);
        MandrillMessage message = new MandrillMessage();

        ArrayList<MandrillMessage.Recipient> recipients = new ArrayList<MandrillMessage.Recipient>();
        MandrillMessage.Recipient recipient = new MandrillMessage.Recipient();
        recipient.setEmail(toEmail);
        recipients.add(recipient);

        message.setTo(recipients);
        message.setPreserveRecipients(true);

        if (attachments != null && attachments.size() > 0) {
             message.setAttachments(attachments);
        }

        final HashMap<String,String> templateContent =
            new HashMap<String,String>();
        templateContent.put("content", "example content");
        mandrillApi.messages().sendTemplate("download-link-from-lantern-website",
                templateContent, message, null);
    }   
}  
