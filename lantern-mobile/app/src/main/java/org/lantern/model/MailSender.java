package org.lantern.model;

import com.microtripit.mandrillapp.lutung.MandrillApi;
import com.microtripit.mandrillapp.lutung.view.MandrillMessage;
import com.microtripit.mandrillapp.lutung.view.MandrillMessage.MergeVar;
import com.microtripit.mandrillapp.lutung.view.MandrillMessage.MergeVarBucket;
import com.microtripit.mandrillapp.lutung.view.MandrillMessageStatus;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.List;

import android.util.Log;

import org.lantern.LanternApp;
import org.lantern.model.SessionManager;

public class MailSender {   

    private static final String TAG = "MailSender";
    private final String apiKey = "fmYlUdjEpGGonI4NDx9xeA";

    public synchronized void sendLogs(String logsFile) {

        try {
            SessionManager session = LanternApp.getSession();

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

            final HashMap<String,String> templateContent =
                new HashMap<String,String>();
            final MergeVar[] mergeValues = {
                new MergeVar("protoken", session.Token()),
                new MergeVar("deviceid", session.DeviceId()),
                new MergeVar("emailaddress", session.Email()),
                new MergeVar("phonenumber", session.PhoneNumber())
            };

            sendMail("todd@getlantern.org", "user-send-logs", mergeValues, attachments);
        } catch (Exception e) {
            Log.e(TAG, "Error sending log messages", e);
        }
    }

    public synchronized void sendMail(String toEmail) throws Exception {

        final MergeVar[] mergeValues = {};

        sendMail(toEmail, "download-link-from-lantern-website", mergeValues, null);
    }

    public synchronized void sendMail(String toEmail, String template, final MergeVar[] mergeValues, List<MandrillMessage.MessageContent> attachments) throws Exception {


        final Map<String, String> templateContent = new HashMap<String, String>();
        for (MergeVar value : mergeValues)
        {
            templateContent.put(value.getName(), value.getContent().toString());
        }

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


        final MandrillMessage.MergeVarBucket mergeBucket = new MandrillMessage.MergeVarBucket();
        mergeBucket.setRcpt(toEmail);
        mergeBucket.setVars(mergeValues);

        final List<MergeVarBucket> mergeBuckets = new ArrayList<MergeVarBucket>();
        mergeBuckets.add(mergeBucket);

        message.setMergeVars(mergeBuckets);

        mandrillApi.messages().sendTemplate(template,
                templateContent, message, null);
    }   
}  
