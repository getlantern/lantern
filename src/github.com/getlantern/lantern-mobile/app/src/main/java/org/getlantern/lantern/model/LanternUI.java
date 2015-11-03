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
import android.os.Build;
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
import android.text.Editable;
import android.text.Html;
import android.text.TextWatcher;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.LayoutInflater;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.RelativeLayout;
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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.getlantern.lantern.activity.LanternMainActivity;
import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.model.GmailSender;
import org.getlantern.lantern.R;
import org.getlantern.lantern.service.LanternVpn;

public class LanternUI {

    private static final String TAG = "LanternUI";

    private ArrayList<NavItem> mNavItems;
    private Map<String, Command> menuMap;

    private DrawerLayout mDrawerLayout;
    private ObjectAnimator colorFadeIn, colorFadeOut;

    private RelativeLayout mDrawerPane;
    private ListView mDrawerList;

    private ActionBarDrawerToggle mDrawerToggle;
    private ImageView settingsIcon;

    private LayoutInflater inflater;

    private ImageView statusImage;
    private Toast statusToast;

    private SharedPreferences mPrefs = null;
    final private Shareable shareable;
    final private LanternMainActivity activity;

    private ToggleButton powerLantern;
    private EditText emailInput;
    private Button sendBtn;
    private View separator;

    private static final int onColor = Color.parseColor("#39C2D6");
    private static final int offColor = Color.parseColor("#FAFBFB"); 

    ColorDrawable[] offTransColor = {new ColorDrawable(offColor), new ColorDrawable(onColor)};
    ColorDrawable[] onTransColor = {new ColorDrawable(onColor), new ColorDrawable(offColor)};     

    private TransitionDrawable offNavTrans = new TransitionDrawable(offTransColor);
    private TransitionDrawable onNavTrans = new TransitionDrawable(onTransColor);


    private View mainView, desktopView, statusLayout;

    public LanternUI(LanternMainActivity activity, SharedPreferences mPrefs) {
        this.mNavItems = new ArrayList<NavItem>();
        this.activity = activity;
        this.mPrefs = mPrefs;

        this.mainView = (View)this.activity.findViewById(R.id.mainView); 
        this.desktopView = (View)this.activity.findViewById(R.id.desktopView);
        this.emailInput = (EditText)this.activity.findViewById(R.id.sendEmail);
        this.sendBtn = (Button)activity.findViewById(R.id.sendBtn);
        this.separator = (View)activity.findViewById(R.id.separator);

        // DrawerLayout
        this.mDrawerLayout = (DrawerLayout) this.activity.findViewById(R.id.drawerLayout);

        this.colorFadeIn = ObjectAnimator.ofObject((View)mDrawerLayout, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        this.colorFadeOut = ObjectAnimator.ofObject((View)mDrawerLayout, "backgroundColor", new ArgbEvaluator(), onColor, offColor);

        this.colorFadeIn.setDuration(500);
        this.colorFadeOut.setDuration(500);

        this.powerLantern = (ToggleButton)this.activity.findViewById(R.id.powerLantern);

        this.shareable = new Shareable(this.activity);

        this.menuMap = new HashMap<String, Command>();

        this.configureEmailInput();
    }

    interface Command {
        void runCommand();
    }

    public void setupSideMenu() throws Exception {

        mNavItems.add(new NavItem("Share", R.drawable.ic_share));
        mNavItems.add(new NavItem("Desktop Version", R.drawable.ic_desktop));
        mNavItems.add(new NavItem("Contact", R.drawable.ic_contact));
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
            public void runCommand() { shareable.showOption(); } 
        });   

        // Populate the Navigtion Drawer with options
        mDrawerPane = (RelativeLayout) this.activity.findViewById(R.id.drawerPane);
        mDrawerList = (ListView) this.activity.findViewById(R.id.navList);
        ListAdapter adapter = new ListAdapter(this.activity, mNavItems);
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

        ImageView backBtn = (ImageView)this.activity.findViewById(R.id.navAvatar);

        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mainView.setVisibility(View.VISIBLE);
                desktopView.setVisibility(View.INVISIBLE);

                mDrawerLayout.closeDrawers();
            }
        });

        profileBox.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v) {
                mainView.setVisibility(View.VISIBLE);
                desktopView.setVisibility(View.INVISIBLE);

                mDrawerLayout.closeDrawers();
            }
        });
    }

    private void desktopOption() {
        mainView.setVisibility(View.INVISIBLE);
        desktopView.setVisibility(View.VISIBLE);
    }

    private static boolean isEmailValid(String email) {
        boolean isValid = false;

        String expression = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{2,4}$";
        CharSequence inputStr = email;

        Pattern pattern = Pattern.compile(expression, Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(inputStr);
        if (matcher.matches()) {
            isValid = true;
        }
        return isValid;
    }

    public void sendDesktopVersion(View view) {
        final String body = "Thank you for contacting the Lantern team. Lantern uses a combination of techniques, including proxies and peer-to-peer, to access the censored web sites.\n" +
            "The latest version of Lantern can be downloaded from the following links.\n\n" +
            "Windows XP SP3 and above:\nhttps://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer.exe\n\n" +
            "Mac OSX 64-bit:\nhttps://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer.dmg\n\n" +
            "32-bit Ubuntu 14.04 and above:\nhttps://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-32-bit.deb\n\n" +
            "64-bit Ubuntu 14.04 and above:\nhttps://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-64-bit.deb\n\n" +
            "Android:\nhttps://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer.apk\n\n" + 
            "Thanks!\nLantern\n";
        final String email = emailInput.getText().toString();
        final GmailSender sender = new GmailSender("lanterngfw77@gmail.com", "irequiremorefluffypillows");

        Log.d(TAG, "Sending Lantern Desktop to " + email);

        new AsyncTask<Void, Void, Void>() {
            @Override 
            public Void doInBackground(Void... arg) {
                try {
                    sender.sendMail("Your Lantern Download Link", body, "team@getlantern.org", email);
                } catch (Exception e) {
                    Log.e(TAG, e.getMessage(), e);     
                }
                return null;
            }
        }.execute();

        String msg = this.activity.getResources().getString(R.string.success_email);

        AlertDialog alertDialog = new AlertDialog.Builder(this.activity).create();
        alertDialog.setTitle("Lantern");
        alertDialog.setMessage(msg);
        alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        dialog.dismiss();
                    }
                });
        alertDialog.show();


        // revert send button, separator back to defaults
        sendBtn.setBackgroundResource(R.drawable.send_btn);
        sendBtn.setClickable(false);
        separator.setBackgroundResource(R.color.edittext_color);
        emailInput.setText("");
    }

    private void configureEmailInput() {

        final LanternMainActivity activity = this.activity;

        emailInput.addTextChangedListener(new TextWatcher() {
            public void afterTextChanged(Editable s) {
                if (s.length() == 0) {
                    separator.setBackgroundResource(R.color.edittext_color);
                } else {
                    separator.setBackgroundResource(R.color.blue_color);
                }
            }

            public void beforeTextChanged(CharSequence s, int start,
                    int count, int after) {
            }

            public void onTextChanged(CharSequence s, int start,
                    int before, int count) {
                if (isEmailValid(s.toString())) {
                    sendBtn.setBackgroundResource(R.drawable.send_btn_blue);
                    sendBtn.setClickable(true);
                } else {
                    sendBtn.setBackgroundResource(R.drawable.send_btn);
                    sendBtn.setClickable(false);
                }
            }

        });

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

        /*actionBar = this.activity.getSupportActionBar();
        actionBar.setDisplayHomeAsUpEnabled(true);
        actionBar.setDisplayShowTitleEnabled(false);
        actionBar.setBackgroundDrawable(new ColorDrawable(android.graphics.Color.TRANSPARENT));*/

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
