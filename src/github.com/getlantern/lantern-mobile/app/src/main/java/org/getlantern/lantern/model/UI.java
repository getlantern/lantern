package org.getlantern.lantern.model;

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
import android.os.Looper;
import android.os.Parcelable;
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
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.ActionBar;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.app.ActionBarDrawerToggle;
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

import org.getlantern.lantern.activity.LanternMainActivity;
import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.R;
import org.getlantern.lantern.service.LanternVpn;

public class UI {

    private static final String TAG = "SideMenu";

    private ArrayList<NavItem> mNavItems;
    private Map<String, Command> menuMap;

    private DrawerLayout mDrawerLayout;
    private ObjectAnimator colorFadeIn, colorFadeOut;

    private RelativeLayout mDrawerPane;
    private ListView mDrawerList;

    private ActionBarDrawerToggle mDrawerToggle;
    private ActionBar actionBar;

    private LayoutInflater inflater;

    private ImageView statusImage;
    private Toast statusToast;

    private SharedPreferences mPrefs = null;
    private ToggleButton powerLantern;

    private static final int onColor = Color.parseColor("#39C2D6");
    private static final int offColor = Color.parseColor("#FAFBFB"); 

    ColorDrawable[] offTransColor = {new ColorDrawable(offColor), new ColorDrawable(onColor)};
    ColorDrawable[] onTransColor = {new ColorDrawable(onColor), new ColorDrawable(offColor)};     

    private TransitionDrawable offNavTrans = new TransitionDrawable(offTransColor);
    private TransitionDrawable onNavTrans = new TransitionDrawable(onTransColor);


    private View mainView, desktopView, statusLayout;
    private LanternMainActivity activity;

    public UI(LanternMainActivity activity, SharedPreferences mPrefs) {
        this.mNavItems = new ArrayList<NavItem>();
        this.activity = activity;
        this.mPrefs = mPrefs;

        this.mainView = (View)this.activity.findViewById(R.id.mainView); 
        this.desktopView = (View)this.activity.findViewById(R.id.desktopView);

        this.colorFadeIn = ObjectAnimator.ofObject(mainView, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        this.colorFadeOut = ObjectAnimator.ofObject(mainView, "backgroundColor", new ArgbEvaluator(), onColor, offColor);

        this.colorFadeIn.setDuration(500);
        this.colorFadeOut.setDuration(500);

        this.powerLantern = (ToggleButton)this.activity.findViewById(R.id.powerLantern);

        // DrawerLayout
        this.mDrawerLayout = (DrawerLayout) this.activity.findViewById(R.id.drawerLayout);

        this.menuMap = new HashMap<String, Command>();
    }

    interface Command {
        void runCommand();
    }

    public void setupSideMenu() throws Exception {

        final LanternMainActivity activity = this.activity;

        mNavItems.add(new NavItem("Share", R.drawable.ic_share));
        mNavItems.add(new NavItem("Desktop Version", R.drawable.ic_desktop));
        mNavItems.add(new NavItem("Contact", R.drawable.ic_contact));
        mNavItems.add(new NavItem("Privacy Policy", R.drawable.ic_privacy_policy));
        mNavItems.add(new NavItem("Quit", R.drawable.ic_quit));

        menuMap.put("Quit", new Command() { 
            public void runCommand() { activity.quitLantern(); } 
        });

        menuMap.put("Contact", new Command() { 
            public void runCommand() { contactOption(); } 
        });

        menuMap.put("Desktop Version", new Command() { 
            public void runCommand() { desktopOption(); } 
        });

        menuMap.put("Share", new Command() { 
            public void runCommand() { activity.customShareOption(); } 
        });   

        // Populate the Navigtion Drawer with options
        mDrawerPane = (RelativeLayout) this.activity.findViewById(R.id.drawerPane);
        mDrawerList = (ListView) this.activity.findViewById(R.id.navList);
        ListAdapter adapter = new ListAdapter(this.activity, mNavItems);
        mDrawerList.setAdapter(adapter);

        // Drawer Item click listeners
        mDrawerList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                selectItemFromDrawer(position);
            }
        });


        mDrawerToggle = new ActionBarDrawerToggle(this.activity, mDrawerLayout, R.string.drawer_open, R.string.drawer_close) {
            @Override
            public void onDrawerOpened(View drawerView) {
                super.onDrawerOpened(drawerView);
                activity.invalidateOptionsMenu();
            }

            @Override
            public void onDrawerClosed(View drawerView) {
                super.onDrawerClosed(drawerView);
                Log.d(TAG, "onDrawerClosed: " + activity.getTitle());
                activity.invalidateOptionsMenu();
            }
        };

        mDrawerLayout.setDrawerListener(mDrawerToggle);

        RelativeLayout profileBox = (RelativeLayout)this.activity.findViewById(R.id.profileBox);

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

    private void desktopOption() {
        mainView.setVisibility(View.INVISIBLE);
        desktopView.setVisibility(View.VISIBLE);
    }

    public File getApkFile(Context context, String packageName) {
        HashMap<String, String> installedApkFilePaths = getAllInstalledApkFiles(context);
        File apkFile = new File(installedApkFilePaths.get(packageName));
        if (apkFile.exists()) {
            return apkFile;
        }

        return null;
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


    private boolean isValid(List<PackageInfo> packageInfos) {
        return packageInfos != null && !packageInfos.isEmpty();
    }
   
    // opens an e-mail message with some default options
    private void contactOption() {

        File f = getApkFile(this.activity, "org.getlantern.lantern");
        String contactEmail = this.activity.getResources().getString(R.string.contact_email);

        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType("plain/text");
        intent.putExtra(Intent.EXTRA_EMAIL, new String[] { contactEmail });
        intent.putExtra(Intent.EXTRA_SUBJECT, R.string.contact_subject);
        intent.putExtra(Intent.EXTRA_TEXT, R.string.contact_message);

        Uri uri = Uri.parse("file://" + f);
        intent.putExtra(Intent.EXTRA_STREAM, uri);

        this.activity.startActivity(Intent.createChooser(intent, ""));
    }

    public boolean useVpn() {
        return mPrefs.getBoolean(LanternConfig.PREF_USE_VPN, false);
    }


    // update START/STOP power Lantern button
    // according to our stored preference
    public void setBtnStatus() {
        boolean useVpn = useVpn();
        powerLantern.setChecked(useVpn);

        if (useVpn) {
            this.mainView.setBackgroundColor(onColor);
            actionBar.setBackgroundDrawable(new ColorDrawable(onColor)); 
        }
    }

    public void displayStatus(final boolean useVpn) {
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override 
            public void run() {
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
        }, 10);
    }

    // initialize and configure status toast (what's displayed
    // whenever we use the on/off slider) 
    public void setupStatusToast() {

        actionBar = this.activity.getSupportActionBar();
        actionBar.setDisplayHomeAsUpEnabled(true);
        actionBar.setDisplayShowTitleEnabled(false);
        actionBar.setBackgroundDrawable(new ColorDrawable(android.graphics.Color.TRANSPARENT));

        onNavTrans.startTransition(500);
        offNavTrans.startTransition(500);

        inflater = this.activity.getLayoutInflater();
        statusLayout = inflater.inflate(R.layout.status_layout, 
                (ViewGroup)this.activity.findViewById(R.id.status_layout_root));
        statusImage = (ImageView)statusLayout.findViewById(R.id.status_image);
        statusToast = new Toast(this.activity.getApplicationContext());
        statusToast.setGravity(Gravity.BOTTOM|Gravity.FILL_HORIZONTAL, 0, 0);
        statusToast.setDuration(Toast.LENGTH_SHORT);
    }

    public void setupLanternSwitch() {

        final LanternMainActivity activity = this.activity;

        setBtnStatus();

        // START/STOP button to enable full-device VPN functionality
        powerLantern.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {

                if (isChecked) {
                    activity.enableVPN();
                } else {
                    activity.stopLantern();
                }
            }
        });
    } 

    public void toggleSwitch(boolean useVpn) {
        displayStatus(useVpn);
        // store the updated preference 
        mPrefs.edit().putBoolean(LanternConfig.PREF_USE_VPN, useVpn).commit();
    }



    public boolean optionSelected(MenuItem item) {
        // Pass the event to ActionBarDrawerToggle
        // If it returns true, then it has handled
        // the nav drawer indicator touch event
        return mDrawerToggle.onOptionsItemSelected(item);
    }

    public void syncState() {
        if (mDrawerToggle != null) {
            mDrawerToggle.syncState();
        }
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
}
