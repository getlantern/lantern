package org.getlantern.lantern.activity;

import android.app.Fragment;
import android.app.FragmentManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.Context;
import android.content.pm.ApplicationInfo; 
import android.content.pm.LabeledIntent;
import android.content.pm.ResolveInfo;
import android.content.res.Resources;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.animation.ArgbEvaluator;
import android.animation.ObjectAnimator;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.TransitionDrawable;
import android.graphics.PorterDuff; 
import android.net.VpnService;
import android.net.Uri;
import android.content.pm.PackageManager;
import android.content.pm.PackageInfo;
import android.support.v7.app.ActionBar;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.app.ActionBarDrawerToggle;
import android.support.v4.widget.DrawerLayout;
import android.text.Html;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.LayoutInflater;
import android.widget.AdapterView;
import android.widget.CompoundButton;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.RelativeLayout;
import android.widget.Toast;
import android.widget.ToggleButton;
import android.view.MenuItem; 
import android.view.View;
import android.view.ViewGroup;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.R;
import org.getlantern.lantern.service.LanternVpn;


public class LanternMainActivity extends ActionBarActivity implements Handler.Callback {

    private static final String TAG = "LanternMainActivity";
    private static final String PREFS_NAME = "LanternPrefs";

    private static final int onColor = Color.parseColor("#39C2D6");
    private static final int offColor = Color.parseColor("#FAFBFB"); 

    ColorDrawable[] offTransColor = {new ColorDrawable(offColor), new ColorDrawable(onColor)};
    ColorDrawable[] onTransColor = {new ColorDrawable(onColor), new ColorDrawable(offColor)};     

    private TransitionDrawable offNavTrans = new TransitionDrawable(offTransColor);
    private TransitionDrawable onNavTrans = new TransitionDrawable(onTransColor);


    private SharedPreferences mPrefs = null;

    private ToggleButton powerLantern;
    private Handler mHandler;
    private LayoutInflater inflater;
    private ObjectAnimator colorFadeIn, colorFadeOut;
    private View mainView, desktopView;
    private View statusLayout;
    private ImageView statusImage;
    private Toast statusToast;

    private Map<String, Command> menuMap = new HashMap<String, Command>();


    ListView mDrawerList;
    RelativeLayout mDrawerPane;
    private ActionBarDrawerToggle mDrawerToggle;
    private ActionBar actionBar;
    private DrawerLayout mDrawerLayout;

    ArrayList<NavItem> mNavItems = new ArrayList<NavItem>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (getIntent().getBooleanExtra("EXIT", false)) {
            finish();
            return;
        }

        mPrefs = getSharedPrefs(getApplicationContext());

        setContentView(R.layout.activity_lantern_main);

        // setup our side menu
        try { 
            setupSideMenu();
        } catch (Exception e) {
            Log.d(TAG, "Got an exception " + e);
        }

        // initialize and configure status toast (what's displayed
        // whenever we use the on/off slider) 
        setupStatusToast();
        // configure actions to be taken whenever slider changes state
        setupLanternSwitch();
    }

    @Override
    protected void onResume() {
        super.onResume();

        // we check if mPrefs has been initialized before
        // since onCreate and onResume are always both called
        if (mPrefs != null) {
            setBtnStatus();
        }
    }

    @Override
    protected void onDestroy() {
        try {
            if (mPrefs != null) {
                mPrefs.edit().remove(LanternConfig.PREF_USE_VPN);
                mPrefs.edit().clear().commit();
            }
            stopLantern();
            // give Lantern a second to stop
            Thread.sleep(1000);
        } catch (Exception e) {

        }
        super.onDestroy();
    }

    interface Command {
        void runCommand();
    }

    private void setupSideMenu() throws Exception {
        mNavItems.add(new NavItem("Share", R.drawable.ic_share));
        mNavItems.add(new NavItem("Desktop Version", R.drawable.ic_desktop));
        mNavItems.add(new NavItem("Contact", R.drawable.ic_contact));
        mNavItems.add(new NavItem("Privacy Policy", R.drawable.ic_privacy_policy));
        mNavItems.add(new NavItem("Quit", R.drawable.ic_quit));

        menuMap.put("Quit", new Command() { 
            public void runCommand() { quitLantern(); } 
        });

        menuMap.put("Contact", new Command() { 
            public void runCommand() { contactOption(); } 
        });

        menuMap.put("Desktop Version", new Command() { 
            public void runCommand() { desktopOption(); } 
        });

        menuMap.put("Share", new Command() { 
            public void runCommand() { customShareOption(); } 
        });   

        // DrawerLayout
        mDrawerLayout = (DrawerLayout) findViewById(R.id.drawerLayout);

        // Populate the Navigtion Drawer with options
        mDrawerPane = (RelativeLayout) findViewById(R.id.drawerPane);
        mDrawerList = (ListView) findViewById(R.id.navList);
        ListAdapter adapter = new ListAdapter(this, mNavItems);
        mDrawerList.setAdapter(adapter);

        // Drawer Item click listeners
        mDrawerList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                selectItemFromDrawer(position);
            }
        });


        mDrawerToggle = new ActionBarDrawerToggle(this, mDrawerLayout, R.string.drawer_open, R.string.drawer_close) {
            @Override
            public void onDrawerOpened(View drawerView) {
                super.onDrawerOpened(drawerView);
                invalidateOptionsMenu();
            }

            @Override
            public void onDrawerClosed(View drawerView) {
                super.onDrawerClosed(drawerView);
                Log.d(TAG, "onDrawerClosed: " + getTitle());
                invalidateOptionsMenu();
            }
        };
        mDrawerLayout.setDrawerListener(mDrawerToggle);

        RelativeLayout profileBox = (RelativeLayout)findViewById(R.id.profileBox);

        profileBox.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){
                mainView.setVisibility(View.VISIBLE);
                desktopView.setVisibility(View.INVISIBLE);

                mDrawerLayout.closeDrawers();
            }
        });

        //mDrawerToggle.setDrawerIndicatorEnabled(false); //disable "hamburger to arrow" drawable
        //mDrawerToggle.setHomeAsUpIndicator(R.drawable.menu); //set your own
    }


    private void selectItemFromDrawer(int position) {
        mDrawerList.setItemChecked(position, true);

        try {
            String title = mNavItems.get(position).mTitle;

            Log.d(TAG, "Menu option " + title + " selected");
            menuMap.get(title).runCommand();

        } catch (Exception e) {

        }

        // Close the drawer
        mDrawerLayout.closeDrawer(mDrawerPane);
    }
    
    private void quitLantern() {
        try {
            stopLantern();
            if (mPrefs != null) {
                mPrefs.edit().remove(LanternConfig.PREF_USE_VPN).commit();
            }

            Log.d(TAG, "About to exit Lantern...");
            // sleep for a few ms before exiting
            Thread.sleep(200);

            finish();
            moveTaskToBack(true);

        } catch (Exception e) {

        }
    }


    private HashMap<String, String> getAllInstalledApkFiles(Context context) {
        HashMap<String, String> installedApkFilePaths = new HashMap<>();

        PackageManager packageManager = context.getPackageManager();
        List<PackageInfo> packageInfoList = packageManager.getInstalledPackages(PackageManager.SIGNATURE_MATCH);

        if (isValid(packageInfoList)) {

            final PackageManager pm = getApplicationContext().getPackageManager();

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

    private void customShareOption() {
        Resources resources = getResources();

        Intent emailIntent = new Intent();
        emailIntent.setAction(Intent.ACTION_SEND);
        // Native email client doesn't currently support HTML, but it doesn't hurt to try in case they fix it
        emailIntent.putExtra(Intent.EXTRA_TEXT, Html.fromHtml(resources.getString(R.string.share_email_native)));
        emailIntent.putExtra(Intent.EXTRA_SUBJECT, resources.getString(R.string.share_email_subject));
        emailIntent.setType("message/rfc822");

        PackageManager pm = getPackageManager();
        Intent sendIntent = new Intent(Intent.ACTION_SEND);     
        sendIntent.setType("text/plain");


        Intent openInChooser = Intent.createChooser(emailIntent, resources.getString(R.string.share_chooser_text));

        List<ResolveInfo> resInfo = pm.queryIntentActivities(sendIntent, 0);
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

                intentList.add(new LabeledIntent(intent, packageName, ri.loadLabel(pm), ri.icon));
            }
        }

        // convert intentList to array
        LabeledIntent[] extraIntents = intentList.toArray( new LabeledIntent[ intentList.size() ]);

        openInChooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, extraIntents);
        startActivity(openInChooser);     
    }

    // opens an e-mail message with some default options
    private void contactOption() {


        File f = getApkFile(this, "org.getlantern.lantern");

        String contactEmail = getResources().getString(R.string.contact_email);

        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType("plain/text");
        intent.putExtra(Intent.EXTRA_EMAIL, new String[] { contactEmail });
        intent.putExtra(Intent.EXTRA_SUBJECT, R.string.contact_subject);
        intent.putExtra(Intent.EXTRA_TEXT, R.string.contact_message);

        Uri uri = Uri.parse("file://" + f);
        intent.putExtra(Intent.EXTRA_STREAM, uri);

        startActivity(Intent.createChooser(intent, ""));
    }

    // this prompts the user to enter their e-mail address
    // to receive Lantern Desktop by e-mail
    private void desktopOption() {
        mainView.setVisibility(View.INVISIBLE);
        desktopView.setVisibility(View.VISIBLE);
    }

    // START/STOP button to enable full-device VPN functionality
    private void setupLanternSwitch() {

        powerLantern = (ToggleButton)findViewById(R.id.powerLantern);
        setBtnStatus();

        // START/STOP button to enable full-device VPN functionality
        powerLantern.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                boolean useVpn;
                if (isChecked) {
                    enableVPN();
                    useVpn = true;
                } else {
                    stopLantern();
                    useVpn = false;
                }
                // display status message at bottom of screen
                displayStatus(useVpn);

                // store the updated preference 
                mPrefs.edit().putBoolean(LanternConfig.PREF_USE_VPN, useVpn).commit();

            }
        });
    } 

    // A toast feedback that displays whenever the ON/OFF switch is toggled
    private void setupStatusToast() {

        mainView = (View)findViewById(R.id.mainView); 
        desktopView = (View)findViewById(R.id.desktopView);

        // when we switch from 'off' to 'on', we use a 1 second 
        // fade to animate the background color
        colorFadeIn = ObjectAnimator.ofObject(mainView, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        colorFadeOut = ObjectAnimator.ofObject(mainView, "backgroundColor", new ArgbEvaluator(), onColor, offColor);
        colorFadeIn.setDuration(500);
        colorFadeOut.setDuration(500);

        actionBar = getSupportActionBar();
        actionBar.setDisplayHomeAsUpEnabled(true);
        actionBar.setDisplayShowTitleEnabled(false);
        actionBar.setBackgroundDrawable(new ColorDrawable(android.graphics.Color.TRANSPARENT));

        onNavTrans.startTransition(500);
        offNavTrans.startTransition(500);


        inflater = getLayoutInflater();
        statusLayout = inflater.inflate(R.layout.status_layout, 
                (ViewGroup)findViewById(R.id.status_layout_root));
        statusImage = (ImageView)statusLayout.findViewById(R.id.status_image);
        statusToast = new Toast(getApplicationContext());
        statusToast.setGravity(Gravity.BOTTOM|Gravity.FILL_HORIZONTAL, 0, 0);
        statusToast.setDuration(Toast.LENGTH_SHORT);
    }

    private void displayStatus(boolean useVpn) {
        if (useVpn) {
            // whenever we switch 'on', we want to trigger the color
            // fade for the background color animation and switch
            // our image view to use the 'on' image resource
            colorFadeIn.start();
            actionBar.setBackgroundDrawable(offNavTrans); 
            statusImage.setImageResource(R.drawable.toast_on);
        } else {
            colorFadeOut.start();
            actionBar.setBackgroundDrawable(onNavTrans); 
            statusImage.setImageResource(R.drawable.toast_off); 
        }
        statusToast.setView(statusLayout);
        statusToast.show();
    }

    // update START/STOP power Lantern button
    // according to our stored preference
    public void setBtnStatus() {
        boolean useVPN = useVpn();
        powerLantern.setChecked(useVPN);
        if (useVPN) {
            this.mainView.setBackgroundColor(onColor);
            actionBar.setBackgroundDrawable(new ColorDrawable(onColor)); 
        }
    }

    public SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public boolean useVpn() {
        return mPrefs.getBoolean(LanternConfig.PREF_USE_VPN, false);
    }

    @Override
    public boolean handleMessage(Message message) {
        if (message != null) {
            //Toast.makeText(this, message.what, Toast.LENGTH_SHORT).show();
        }
        return true;
    }

    // Prompt the user to enable full-device VPN mode
    protected void enableVPN() {
        Log.d(TAG, "Load VPN configuration");
        Thread thread = new Thread() {
            public void run() { 
                Intent intent = new Intent(LanternMainActivity.this, PromptVpnActivity.class);
                if (intent != null) {
                    startActivity(intent);
                }
            }
        };
        thread.start();
    }

    protected void stopLantern() {
        Log.d(TAG, "Stopping Lantern...");
        try {
            Thread thread = new Thread() {
                public void run() { 

                    Intent service = new Intent(LanternMainActivity.this, LanternVpn.class);
                    if (service != null) {
                        service.setAction(LanternConfig.DISABLE_VPN);
                        startService(service);
                    }
                }
            };
            thread.start();
        } catch (Exception e) {
            Log.d(TAG, "Got an exception trying to stop Lantern: " + e);
        }
    }


    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Pass the event to ActionBarDrawerToggle
        // If it returns true, then it has handled
        // the nav drawer indicator touch event
        if (mDrawerToggle.onOptionsItemSelected(item)) {
            return true;
        }

        // Handle your other action bar items...

        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onPostCreate(Bundle savedInstanceState) {
        super.onPostCreate(savedInstanceState);
        if (mDrawerToggle != null) {
            mDrawerToggle.syncState();
        }
    }
}
