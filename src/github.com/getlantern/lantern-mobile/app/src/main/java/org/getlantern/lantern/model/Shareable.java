package org.getlantern.lantern.model;

import android.content.Intent;
import android.content.Context;
import android.content.pm.ApplicationInfo; 
import android.content.pm.LabeledIntent;
import android.content.pm.ResolveInfo;
import android.content.res.Resources;
import android.content.pm.PackageManager;
import android.content.pm.PackageInfo;
import android.text.Html;
import android.content.ComponentName;
import android.net.Uri;
import android.util.Log;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.getlantern.lantern.R;
import org.getlantern.lantern.activity.LanternMainActivity;

public class Shareable {
    private static final String TAG = "Shareable";

    final private Resources resources;
    final private PackageManager packageManager;
    final private LanternMainActivity activity;

    public Shareable(final LanternMainActivity activity) {
        this.activity = activity;
        this.resources = activity.getResources();
        this.packageManager = activity.getPackageManager();
    }

    public File getApkFile(Context context, String packageName) {
        HashMap<String, String> installedApkFilePaths = getAllInstalledApkFiles(context);
        File apkFile = new File(installedApkFilePaths.get(packageName));
        if (apkFile.exists()) {
            return apkFile;
        }

        return null;
    }

    private boolean isValid(List<PackageInfo> packageInfos) {
        return packageInfos != null && !packageInfos.isEmpty();
    }

    private HashMap<String, String> getAllInstalledApkFiles(Context context) {
        HashMap<String, String> installedApkFilePaths = new HashMap<>();

        PackageManager packageManager = context.getPackageManager();
        List<PackageInfo> packageInfoList = packageManager.getInstalledPackages(PackageManager.SIGNATURE_MATCH);

        if (isValid(packageInfoList)) {

            final PackageManager pm = this.activity.getApplicationContext().getPackageManager();

            for (PackageInfo packageInfo : packageInfoList) {
                ApplicationInfo applicationInfo;

                try {
                    applicationInfo = pm.getApplicationInfo(packageInfo.packageName, 0);

                    String packageName = applicationInfo.packageName;
                    String versionName = packageInfo.versionName;
                    int versionCode = packageInfo.versionCode;

                    File apkFile = new File(applicationInfo.publicSourceDir);
                    if (apkFile.exists()) {
                        installedApkFilePaths.put(packageName, apkFile.getAbsolutePath());
                        Log.d(TAG, packageName + " = " + apkFile.getName());
                    }
                } catch (PackageManager.NameNotFoundException error) {
                    error.printStackTrace();
                }
            }
        }

        return installedApkFilePaths;
    }




    public void showOption() {

        Intent emailIntent = new Intent();
        emailIntent.setAction(Intent.ACTION_SEND);
        // Native email client doesn't currently support HTML, but it doesn't hurt to try in case they fix it
        emailIntent.putExtra(Intent.EXTRA_TEXT, Html.fromHtml(resources.getString(R.string.share_email_native)));
        emailIntent.putExtra(Intent.EXTRA_SUBJECT, resources.getString(R.string.share_email_subject));
        emailIntent.setType("message/rfc822");

        Intent sendIntent = new Intent(Intent.ACTION_SEND);     
        sendIntent.setType("text/plain");


        Intent openInChooser = Intent.createChooser(emailIntent, resources.getString(R.string.share_chooser_text));

        List<ResolveInfo> resInfo = this.packageManager.queryIntentActivities(sendIntent, 0);
        List<LabeledIntent> intentList = new ArrayList<LabeledIntent>();        
        

        for (int i = 0; i < resInfo.size(); i++) {
            // Extract the label, append it, and repackage it in a LabeledIntent
            ResolveInfo ri = resInfo.get(i);
            String packageName = ri.activityInfo.packageName;
            if(packageName.contains("android.email")) {
                emailIntent.setPackage(packageName);

            } else if ("com.twitter.android.composer.ComposerActivity".equals(ri.activityInfo.name) || 
                packageName.contains("facebook") || 
                "com.tencent.mm.ui.tools.ShareImgUI".equals(ri.activityInfo.name) ||
                packageName.contains("weibo") ||
                packageName.contains("mms") || packageName.contains("android.gm")) {
                
                Intent intent = new Intent();
                intent.setComponent(new ComponentName(packageName, ri.activityInfo.name));
                intent.setAction(Intent.ACTION_SEND);
                intent.setType("text/plain");
                if(packageName.contains("twitter") || packageName.contains("tencent.mm")) {
                    intent.putExtra(Intent.EXTRA_TEXT, resources.getString(R.string.share_twitter));
                } else if(packageName.contains("facebook")) {
                    // Warning: Facebook IGNORES our text. They say "These fields are intended for users to express themselves. Pre-filling these fields erodes the authenticity of the user voice."
                    // One workaround is to use the Facebook SDK to post, but that doesn't allow the user to choose how they want to share. We can also make a custom landing page, and the link
                    // will show the <meta content ="..."> text from that page with our link in Facebook.
                    intent.putExtra(Intent.EXTRA_TEXT, resources.getString(R.string.share_facebook));
                } else if(packageName.contains("mms")) {
                    intent.putExtra(Intent.EXTRA_TEXT, resources.getString(R.string.share_sms));
                } else if(packageName.contains("android.gm")) { // If Gmail shows up twice, try removing this else-if clause and the reference to "android.gm" above
                    
                    intent.putExtra(Intent.EXTRA_TEXT, Html.fromHtml(resources.getString(R.string.share_email_gmail)));
                    intent.putExtra(Intent.EXTRA_SUBJECT, resources.getString(R.string.share_email_subject));               
                    intent.setType("message/rfc822");
                }

                if (packageName.contains("android.gm") || packageName.contains("android.email")) {
                    File f = getApkFile(this.activity, "org.getlantern.lantern");
                    Uri uri = Uri.parse("file://" + f);
                    intent.putExtra(Intent.EXTRA_STREAM, uri);
                }

                intentList.add(new LabeledIntent(intent, packageName, ri.loadLabel(this.packageManager), ri.icon));
            }
        }

        // convert intentList to array
        LabeledIntent[] extraIntents = intentList.toArray( new LabeledIntent[ intentList.size() ]);

        openInChooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, extraIntents);
        activity.startActivity(openInChooser);     
    }

}
