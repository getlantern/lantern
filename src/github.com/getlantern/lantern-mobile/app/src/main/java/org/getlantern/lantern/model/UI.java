package org.getlantern.lantern.model;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.app.Fragment;
import android.app.FragmentManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.Context;
import android.content.res.Resources;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.animation.ArgbEvaluator;
import android.animation.ObjectAnimator;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
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
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ToggleButton;
import android.view.MenuItem; 
import android.view.View;
import android.view.ViewGroup;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import com.google.common.collect.ImmutableMap;

import org.getlantern.lantern.activity.*;
import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.sdk.Utils;
import org.getlantern.lantern.R;

public class UI {

    private static final String TAG = "LanternUI";

    private ArrayList<NavItem> mNavItems;

    private DrawerLayout mDrawerLayout;
    private ObjectAnimator colorFadeIn, colorFadeOut;

    private RelativeLayout mDrawerPane;
    private ListView mDrawerList;

    private ActionBarDrawerToggle mDrawerToggle;
    private ImageView settingsIcon;

    private LayoutInflater inflater;

    private ImageView statusImage;
    private Toast statusToast;

    final private SharedPreferences mPrefs;
    final private Shareable shareable;
    final private LanternMainActivity activity;

    private ToggleButton powerLantern;
    private TextView versionNum;

    private static final int onColor = Color.parseColor("#39C2D6");
    private static final int offColor = Color.parseColor("#FAFBFB"); 

    ColorDrawable[] offTransColor = {new ColorDrawable(offColor), new ColorDrawable(onColor)};
    ColorDrawable[] onTransColor = {new ColorDrawable(onColor), new ColorDrawable(offColor)};     

    private TransitionDrawable offNavTrans = new TransitionDrawable(offTransColor);
    private TransitionDrawable onNavTrans = new TransitionDrawable(onTransColor);

    private View statusLayout;

    static final Map<String, Integer> menuOptions = ImmutableMap.<String, Integer>builder()
        .put("Share", R.drawable.ic_share)
        .put("Sign in to Pro", R.drawable.sign_in)
        .put("Pro Now", R.drawable.pro_now)
        .put("Checkout", R.drawable.ic_quit)
        .put("Get Free Months", R.drawable.get_free)
        .put("Language", R.drawable.language)
        .put("Desktop Version", R.drawable.ic_desktop)
        .put("Contact", R.drawable.ic_contact)
        .put("Welcome", R.drawable.ic_contact)
        .build();

    public UI(LanternMainActivity activity, SharedPreferences mPrefs) {
        this.mNavItems = new ArrayList<NavItem>();

        this.activity = activity;
        this.mPrefs = mPrefs;

        // DrawerLayout
        this.mDrawerLayout = (DrawerLayout) this.activity.findViewById(R.id.drawerLayout);

        this.colorFadeIn = ObjectAnimator.ofObject((View)mDrawerLayout, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        this.colorFadeOut = ObjectAnimator.ofObject((View)mDrawerLayout, "backgroundColor", new ArgbEvaluator(), onColor, offColor);

        this.colorFadeIn.setDuration(500);
        this.colorFadeOut.setDuration(500);

        this.powerLantern = (ToggleButton)this.activity.findViewById(R.id.powerLantern);

        this.shareable = new Shareable(this.activity);

        try { 
            this.setupSideMenu();
        } catch (Exception e) {
            Log.e(TAG, "Error setting up side menu! " + e.getMessage());
        }

        this.setupStatusToast();
    }

    public void setVersionNum(final String latestVersion) {

        this.activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mPrefs.edit().putString("versionNum", latestVersion).commit();

                versionNum.setText(latestVersion);
            }
        });
    }

    public void setupSideMenu() throws Exception {

        for (Map.Entry<String, Integer> entry : menuOptions.entrySet()) {
            mNavItems.add(new NavItem(entry.getKey(), entry.getValue()));
        }

        // Populate the Navigtion Drawer with options
        mDrawerPane = (RelativeLayout) this.activity.findViewById(R.id.drawerPane);
        mDrawerList = (ListView) this.activity.findViewById(R.id.navList);
        ListAdapter adapter = new ListAdapter(this.activity, mNavItems, R.layout.drawer_item);
        mDrawerList.setAdapter(adapter);

        // remove ListView border
        mDrawerList.setDivider(null);

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


        settingsIcon = (ImageView)this.activity.findViewById(R.id.settings_icon);

        settingsIcon.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mDrawerLayout.openDrawer(Gravity.START);
                Log.v(TAG, " click");         
            }        
        });


        mDrawerLayout.setDrawerListener(mDrawerToggle);

        RelativeLayout profileBox = (RelativeLayout)this.activity.findViewById(R.id.profileBox);

        // update version number that appears at the bottom of the side menu
        // if we have it stored in shared preferences; otherwise, default to absent until
        // Lantern starts
        versionNum = (TextView)this.activity.findViewById(R.id.versionNum);
        versionNum.setText(mPrefs.getString("versionNum", ""));

    }

    public void handleFatalError() {
        this.toggleSwitch(false);
        String msg = this.activity.getResources().getString(R.string.fatal_error);
        Utils.showAlertDialog(this.activity, "Lantern", msg);
    }

    // opens an e-mail message with some default options
    private void contactOption() {

        String contactEmail = this.activity.getResources().getString(R.string.contact_email);

        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType("plain/text");
        intent.putExtra(Intent.EXTRA_EMAIL, new String[] { contactEmail });
        intent.putExtra(Intent.EXTRA_SUBJECT, R.string.contact_subject);
        intent.putExtra(Intent.EXTRA_TEXT, R.string.contact_message);

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
            this.mDrawerLayout.setBackgroundColor(onColor);
            settingsIcon.setImageResource(R.drawable.menu_white);   
        } else {
            this.mDrawerLayout.setBackgroundColor(offColor);
            settingsIcon.setImageResource(R.drawable.menu);   
        }
    }

    public void displayStatus(final boolean useVpn) {
        final LanternMainActivity activity = this.activity;
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override 
            public void run() {
                if (useVpn) {
                    // whenever we switch 'on', we want to trigger the color
                    // fade for the background color animation and switch
                    // our image view to use the 'on' image resource
                    colorFadeIn.start();
                    statusImage.setImageResource(R.drawable.toast_on);
                    settingsIcon.setImageResource(R.drawable.menu_white);   
                } else {
                    colorFadeOut.start();
                    statusImage.setImageResource(R.drawable.toast_off); 
                    settingsIcon.setImageResource(R.drawable.menu);
                    powerLantern.setChecked(false);
                }

                statusToast.setView(statusLayout);
                statusToast.show();
            }
        }, 10);
    }

    // initialize and configure status toast (what's displayed
    // whenever we use the on/off slider) 
    public void setupStatusToast() {

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
        powerLantern.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                boolean isChecked = powerLantern.isChecked();

                if (!activity.isNetworkAvailable()) {
                    powerLantern.setChecked(false);
                    Utils.showAlertDialog(activity, "Lantern", "No Internet connection available!");
                    return;
                }

                // disable the on/off switch while the VpnService
                // is updating the connection
                powerLantern.setEnabled(false);

                if (isChecked) {
                    activity.enableVPN();
                } else {
                    toggleSwitch(false);
                    activity.stopLantern();
                }

                // after 2000ms, enable the switch again
                new Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        powerLantern.setEnabled(true);
                    }
                }, 2000);

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

            Intent intent = null;

            switch (title) {
                case "Share":
                    shareable.showOption();
                    break;
                case "Sign in to Pro":
                    intent = new Intent(this.activity, SignInActivity.class);
                    break;
                case "Contact":
                    contactOption();
                    break;
                case "Quit":
                    activity.quitLantern();
                    break;
                case "Desktop Version":
                    intent = new Intent(this.activity, DesktopActivity.class);
                    break;
                case "Pro Now":
                    intent = new Intent(this.activity, PlansActivity.class);
                    break;
                case "Get Free Months":
                    intent = new Intent(this.activity, InviteActivity.class);
                    break;
                case "Language":
                    intent = new Intent(this.activity, LanguageActivity.class);
                    break;
                case "Checkout":
                    intent = new Intent(this.activity, PaymentActivity.class);
                    break;
                case "Welcome":
                    intent = new Intent(this.activity, WelcomeActivity.class);
                    break;
                default:
            }

            if (intent != null) {
                this.activity.startActivity(intent);
            }
        } catch (Exception e) {

        }

        // Close the drawer
        mDrawerLayout.closeDrawer(mDrawerPane);
    }
}
