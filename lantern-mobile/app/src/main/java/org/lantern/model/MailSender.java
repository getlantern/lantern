package org.lantern.model;

import android.app.Activity;
import android.app.ProgressDialog;
import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

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

import org.lantern.LanternApp;
import org.lantern.R;

public class MailSender extends AsyncTask<String, Void, Boolean> {   

    private static final String TAG = "MailSender";
    private final String apiKey = "fmYlUdjEpGGonI4NDx9xeA";

    private ProgressDialog dialog;

    private String fromEmail = "support@getlantern.org";
    private String template;
    private SessionManager session;
    private Context context;
    private String userEmail;
    private boolean sendLogs = false;
    private MergeVar[] mergeValues;
    private List<MandrillMessage.MessageContent> attachments = new ArrayList<MandrillMessage.MessageContent>();

    public MailSender(Context context, String template) {
        this.context = context;
        this.template = template;
        this.session = LanternApp.getSession();

        dialog = new ProgressDialog(context);
        dialog.setCancelable(false);
        dialog.setCanceledOnTouchOutside(false);

        if (template.equals("user-send-logs")) {
            sendLogs = true;
            userEmail = session.Email();
            mergeValues = new MergeVar[]{
                new MergeVar("userid", session.UserId()),
                new MergeVar("protoken", session.Token()),
                new MergeVar("deviceid", session.DeviceId()),
                new MergeVar("emailaddress", userEmail)
            };
        }
    }

    @Override
    protected void onPreExecute() {
        if (dialog != null) {
            dialog.setMessage(context.getResources().getString(R.string.sending_request));
            dialog.show();
        }
    }

    @Override
    protected Boolean doInBackground(String... params) {
        String toEmail = params[0];

        if (template.equals("user-send-logs")) {
            addSendLogs();
            toEmail = "support@getlantern.org";
        }

        final Map<String, String> templateContent = new HashMap<String, String>();
        if (mergeValues != null) {
            for (MergeVar value : mergeValues)
            {
                templateContent.put(value.getName(), value.getContent().toString());
            }
        }

        MandrillApi mandrillApi = new MandrillApi(apiKey);
        MandrillMessage message = new MandrillMessage();

        ArrayList<MandrillMessage.Recipient> recipients = new ArrayList<MandrillMessage.Recipient>();
        MandrillMessage.Recipient recipient = new MandrillMessage.Recipient();
        recipient.setEmail(toEmail);
        recipients.add(recipient);

        if (userEmail != null && !userEmail.equals("")) {
            recipient.setEmail(userEmail);
            recipients.add(recipient);
        }

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

        try {
            mandrillApi.messages().sendTemplate(template,
                    templateContent, message, null); 
        } catch (Exception e) {
            Log.e(TAG, "Error trying to send mail: ", e);
            return false;
        }

        return true;

    }

    private String getResponseMessage(boolean success) {
        int msg;
        if (success) {
            Log.d(TAG, "Successfully called send mail");
            msg = sendLogs ? R.string.success_log_email : R.string.success_email;
        } else {
            msg = sendLogs ? R.string.error_log_email : R.string.error_email;
        }
        return context.getResources().getString(msg);
    }

    @Override
    protected void onPostExecute(Boolean success) {
        super.onPostExecute(success);

        if (dialog != null && dialog.isShowing()) {
            dialog.dismiss();
        }
        Utils.showAlertDialog((Activity)context, "Lantern", getResponseMessage(success), false);
    }

    private void addSendLogs() {
        final String logDir = context.getFilesDir().getAbsolutePath();

        try {
            byte[] bytes = org.apache.commons.io.FileUtils.readFileToByteArray(new File(logDir, ".lantern/lantern.log"));

            MandrillMessage.MessageContent logContent = new MandrillMessage.MessageContent();
            logContent.setType("text/plain");
            logContent.setName("lantern.log");
            org.apache.commons.codec.binary.Base64 base64 = new org.apache.commons.codec.binary.Base64();
            String encoded = new String(base64.encode(bytes));
            logContent.setContent(encoded);

            attachments.add(logContent);
        } catch (Exception e) {
            Log.e(TAG, "Unable to attach log file", e);
        }
    }
}  
