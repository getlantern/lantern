package org.lantern.activity;

import android.animation.ArgbEvaluator;
import android.animation.ObjectAnimator;
import android.app.Application;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.ComponentCallbacks2;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.TransitionDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.StrictMode;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.net.VpnService;
import android.net.wifi.WifiManager;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.ToggleButton;
import android.view.MenuItem;
import android.view.KeyEvent;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.ActionBarDrawerToggle;
import android.support.v7.app.AppCompatActivity;
import android.support.v4.app.Fragment;
import android.support.v4.view.GravityCompat;
import android.support.v4.view.ViewPager;
import android.support.v4.widget.DrawerLayout;

import org.lantern.LanternApp;
import org.lantern.vpn.Service;
import org.lantern.fragment.FeedFragment;
import org.lantern.model.GetFeed;
import org.lantern.model.ListAdapter;
import org.lantern.model.NavItem;
import org.lantern.model.SessionManager;
import org.lantern.model.Shareable;
import org.lantern.model.Utils;
import org.lantern.R;

import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.Click;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.Fullscreen;
import org.androidannotations.annotations.ViewById;

import com.thefinestartist.finestwebview.FinestWebView;
import com.ogaclejapan.smarttablayout.utils.v4.FragmentStatePagerItemAdapter;
import com.ogaclejapan.smarttablayout.utils.v4.FragmentPagerItems;
import com.ogaclejapan.smarttablayout.SmartTabLayout;

import com.kyleduo.switchbutton.SwitchButton;

import go.lantern.Lantern;

@Fullscreen
@EActivity(R.layout.activity_lantern_main)
public class LanternMainActivity extends AppCompatActivity implements
Application.ActivityLifecycleCallbacks, ComponentCallbacks2 {

    private static final String TAG = "LanternMainActivity";
    private static final String PREFS_NAME = "LanternPrefs";
    private final static int REQUEST_VPN = 7777;
    private BroadcastReceiver mReceiver;
    private Context context;
    private String appVersion;

    private boolean isInBackground = false;
    private FragmentStatePagerItemAdapter feedAdapter;
    private SmartTabLayout viewPagerTab;
    private String lastFeedSelected;

    private ObjectAnimator colorFadeIn, colorFadeOut;

    private static final int onColor = Color.parseColor("#00BCD4");
    private static final int offColor = Color.parseColor("#FFFFFF");

    ColorDrawable[] offTransColor = {new ColorDrawable(offColor), new ColorDrawable(onColor)};
    ColorDrawable[] onTransColor = {new ColorDrawable(onColor), new ColorDrawable(offColor)};

    private TransitionDrawable offNavTrans = new TransitionDrawable(offTransColor);
    private TransitionDrawable onNavTrans = new TransitionDrawable(onTransColor);

    private Toast statusToast;
	private ImageView statusImage;
	private TextView statusText;

    private SessionManager session;

    @ViewById
    TextView versionNum, dataRemaining;

    @ViewById
    ProgressBar dataProgressBar;

    @ViewById
    SwitchButton powerLantern;

    @ViewById
    DrawerLayout drawerLayout;

    @ViewById
    RelativeLayout drawerPane;

    @ViewById
    ListView drawerList;

    @ViewById
    View feedError, feedView, dataUsageView;

    @ViewById
    ImageView menuIcon;

    @ViewById
    Button upgradeBtn;

    private ActionBarDrawerToggle mDrawerToggle;

    private View statusLayout;

    @AfterViews
    void afterViews() {

        getApplication().registerActivityLifecycleCallbacks(this);

        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        lastFeedSelected = getResources().getString(R.string.all_feeds);

        // we want to use the ActionBar from the AppCompat
        // support library, but with our custom design
        // we hide the default action bar
        if (getSupportActionBar() != null) {
            getSupportActionBar().hide();
        }

        // make sure to show status bar
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);

        context = getApplicationContext();
        session = LanternApp.getSession();

        // since onCreate is only called when the main activity
        // is first created, we clear shared preferences in case
        // Lantern was forcibly stopped during a previous run
        if (!Service.isRunning(context)) {
            session.clearVpnPreference();
        }

        // the ACTION_SHUTDOWN intent is broadcast when the phone is
        // about to be shutdown. We register a receiver to make sure we
        // clear the preferences and switch the VpnService to the off
        // state when this happens
        IntentFilter filter = new IntentFilter(Intent.ACTION_SHUTDOWN);
        filter.addAction(Intent.ACTION_SHUTDOWN);
        filter.addAction(Intent.ACTION_USER_PRESENT);
        filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
        filter.addAction(WifiManager.SUPPLICANT_CONNECTION_CHANGE_ACTION);

        mReceiver = new LanternReceiver();
        registerReceiver(mReceiver, filter);

        setVersionNum();
        setupStatusToast();
        checkUpdateAfterDelay();

    }

    @Override
    protected void onResume() {
        super.onResume();

        setupSideMenu();
        setBtnStatus();
        setBandwidthQuota();  
        showFeedview();
    }

    private void setBandwidthQuota() {
        if (!session.isProUser()) {
            String quota = Lantern.GetBandwidthQuota();
            String amount = String.format(getResources().getString(R.string.data_remaining), quota);
            dataRemaining.setText(amount);
            if (dataProgressBar != null) {
                Log.d(TAG, "Current bandwidth quota: " + quota);
                dataProgressBar.setProgress(Integer.parseInt(quota));
            }
        } else {
            // hide data usage summary if its a pro user
            dataUsageView.setVisibility(View.INVISIBLE);
        }
    }


    // update START/STOP power Lantern button
    // according to our stored preference
    public void setBtnStatus() {
        boolean useVpn = session.useVpn();
        //powerLantern.setChecked(useVpn);

        if (useVpn) {
            menuIcon.setImageResource(R.drawable.menu_white);
            drawerLayout.setBackgroundColor(onColor);
        } else {
            menuIcon.setImageResource(R.drawable.menu);
            drawerLayout.setBackgroundColor(offColor);
        }
        updateTheme(useVpn);
    }

    private void setButtonStatus(boolean useVpn) {
        if (useVpn) {
            menuIcon.setImageResource(R.drawable.menu_white);
            drawerLayout.setBackgroundColor(onColor);
        } else {
            menuIcon.setImageResource(R.drawable.menu);
            drawerLayout.setBackgroundColor(offColor);
        }

    }

    // initialize and configure status toast (what's displayed
    // whenever we use the on/off slider) 
    public void setupStatusToast() {

        colorFadeIn = ObjectAnimator.ofObject(drawerLayout, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        colorFadeOut = ObjectAnimator.ofObject(drawerLayout, "backgroundColor", new ArgbEvaluator(), onColor, offColor);

        colorFadeIn.setDuration(500);
        colorFadeOut.setDuration(500);

        onNavTrans.startTransition(500);
        offNavTrans.startTransition(500);

        LayoutInflater inflater = getLayoutInflater();
        statusLayout = inflater.inflate(R.layout.status_layout, 
                (ViewGroup)findViewById(R.id.status_layout_root));
		statusImage = (ImageView)statusLayout.findViewById(R.id.statusImage);
		statusText  = (TextView)statusLayout.findViewById(R.id.statusText);
        statusToast = new Toast(getApplicationContext());
        statusToast.setGravity(Gravity.BOTTOM|Gravity.FILL_HORIZONTAL, 0, 0);
        statusToast.setDuration(Toast.LENGTH_SHORT);
    }

    public void displayStatus(final boolean useVpn) {
        if (useVpn) {
            // whenever we switch 'on', we want to trigger the color
            // fade for the background color animation and switch
            // our image view to use the 'on' image resource
            colorFadeIn.start();
            statusImage.setImageResource(R.drawable.status_on_white);
            statusText.setText(getResources().getString(R.string.lantern_on));
            menuIcon.setImageResource(R.drawable.menu_white);
        } else {
            colorFadeOut.start();
            statusImage.setImageResource(R.drawable.status_off_white);
            statusText.setText(getResources().getString(R.string.lantern_off));
            menuIcon.setImageResource(R.drawable.menu);
        }

        statusToast.setView(statusLayout);
        statusToast.show();
    }

    // setVersionNum updates the version number that appears at the 
    // bottom of the side menu
    public void setVersionNum() {
        try {
            // configure actions to be taken whenever slider changes state
            PackageInfo pInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            appVersion = pInfo.versionName;
            Log.d(TAG, "Currently running Lantern version: " + appVersion);

            // update version number that appears at the bottom of the side menu
            versionNum.setText(appVersion);
        } catch (android.content.pm.PackageManager.NameNotFoundException nne) {
            Log.e(TAG, "Could not find package: " + nne.getMessage());
        }
    }

    interface Command {
        void runCommand();
    }

    public void setupSideMenu() {
        final LanternMainActivity activity = this;
        final Resources resources = getResources();

        final Map<String, Command> menuMap = new HashMap<String, Command>();
        final ArrayList<NavItem> navItems = new ArrayList<NavItem>();
        final ListAdapter listAdapter = new ListAdapter(this, navItems);  


        if (!session.isDeviceLinked()) {
            navItems.add(new NavItem(resources.getString(R.string.sign_in_pro), 
                        R.drawable.sign_in));
        }

        if (!session.isProUser()) {
            // 'Get Pro Now' menu option if not already a Pro user
            navItems.add(new NavItem(resources.getString(R.string.get_lantern_pro), R.drawable.pro_now));
        } else {
            navItems.add(navItems.size(), new NavItem(resources.getString(R.string.pro_account_header), 
                        R.drawable.sign_in));
        }

        navItems.add(new NavItem(resources.getString(R.string.check_for_update), R.drawable.ic_update));
        navItems.add(new NavItem(resources.getString(R.string.get_free_months), R.drawable.get_free));
        navItems.add(new NavItem(resources.getString(R.string.desktop_option), R.drawable.ic_desktop));
        navItems.add(new NavItem(resources.getString(R.string.language), R.drawable.language));
        navItems.add(new NavItem(resources.getString(R.string.share_option), R.drawable.ic_share));
        navItems.add(new NavItem(resources.getString(R.string.contact_option), R.drawable.ic_contact));

        if (session.showFeed())  {
            // 'Turn off Feed' when the feed is already shown
            navItems.add(new NavItem(resources.getString(R.string.newsfeed_off_option), R.drawable.ic_feed));
        } else {
            // 'Try Lantern Feed' when the feed is already hidden
            navItems.add(new NavItem(resources.getString(R.string.newsfeed_option), R.drawable.ic_feed));
        }

        navItems.add(new NavItem(resources.getString(R.string.quit_option), 
                    R.drawable.ic_quit));

        menuMap.put(resources.getString(R.string.sign_in_pro), new Command() {
            public void runCommand() {
                Intent intent = new Intent(activity, SignInActivity.class);
                intent.putExtra("signIn", true);
                startActivity(intent);
            } 
        });

        menuMap.put(resources.getString(R.string.pro_account_header), new Command() {
            public void runCommand() {
                startActivity(new Intent(activity, ProAccountActivity_.class));
            }
        });

        menuMap.put(resources.getString(R.string.get_lantern_pro), new Command() {
            public void runCommand() {
                startActivity(new Intent(activity, PlansActivity_.class)); 
            }
        });

        menuMap.put(resources.getString(R.string.get_free_months), new Command() {
            public void runCommand() { startActivity(new Intent(activity, InviteActivity_.class)); }
        });

        menuMap.put(resources.getString(R.string.language), new Command() {
            public void runCommand() { startActivity(new Intent(activity, LanguageActivity_.class)); }
        });

        menuMap.put(resources.getString(R.string.check_for_update), new Command() {
            public void runCommand() {
                checkUpdateAvailable(true);
            }
        });

        menuMap.put(resources.getString(R.string.quit_option), new Command() {
            public void runCommand() { quitLantern(); }
        });

        menuMap.put(resources.getString(R.string.contact_option), new Command() {
            public void runCommand() { contactOption(); }
        });

        menuMap.put(resources.getString(R.string.newsfeed_off_option), new Command() {
            public void runCommand() {
                updateFeedview(listAdapter, navItems, resources, false);
            }
        });

        menuMap.put(resources.getString(R.string.newsfeed_option), new Command() {
            public void runCommand() {
                updateFeedview(listAdapter, navItems, resources, true);
            }
        });

        menuMap.put(resources.getString(R.string.desktop_option), new Command() {
            public void runCommand() {

                Intent intent = new Intent(activity, DesktopActivity_.class);
                startActivity(intent);
            }
        });

        menuMap.put(resources.getString(R.string.share_option), new Command() {
            public void runCommand() {
                final Shareable shareable = new Shareable(activity);
                shareable.showOption();
            }
        });

        // Populate the Navigtion Drawer with options
        drawerList.setAdapter(listAdapter);

        // remove ListView border
        drawerList.setDivider(null);

        // Drawer Item click listeners
        drawerList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                drawerItemClicked(menuMap, navItems, position);
            }
        });

        mDrawerToggle = new ActionBarDrawerToggle(this, drawerLayout, R.string.drawer_open, R.string.drawer_close) {
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

        drawerLayout.setDrawerListener(mDrawerToggle);
    }

    // drawerItemClicked is called whenever an item in the 
    // navigation menu is clicked on
    void drawerItemClicked(final Map<String, Command> menuMap,
            final ArrayList<NavItem> navItems,
            final int position) {

        if (position < 0 || position >= navItems.size()) {
            menuError("Tried to access menu item outside index range"); 
            return;
        }

        drawerList.setItemChecked(position, true);

        NavItem item = navItems.get(position);
        if (item == null) {
            menuError(String.format("Missing navigation item at position: %d", 
                        position));
            return;
        }

        String title = item.getTitle();
        if (title == null) {
            menuError(String.format("Missing item title at position: %d", 
                        position));
            return;
        }

        Command cmd = menuMap.get(title);
        if (cmd != null) {
            Log.d(TAG, "Menu option " + title + " selected");
            cmd.runCommand();
        }

        drawerLayout.closeDrawer(drawerPane);
    }

    // An error occurred performing some action on the 
    // navigation drawer. Log the error and close the drawer
    void menuError(String errMsg) {
        if (errMsg != null) {
            Log.e(TAG, errMsg);
            drawerLayout.closeDrawer(drawerPane);
        }
    }

    @Click(R.id.menuIcon)
    void menuButtonClicked() {
        drawerLayout.openDrawer(GravityCompat.START);
    }

    @Click(R.id.upgradeBtn)
    void ugpradeBtnClicked() {
        startActivity(new Intent(this, PlansActivity_.class)); 
    }

    @Click(R.id.backBtn)
    void backBtnClicked() {
        drawerLayout.closeDrawer(drawerPane);
    }

    private void noUpdateAvailable(boolean showAlert) {
        if (!showAlert) {
            return;
        }

        String noUpdateTitle = getResources().getString(R.string.no_update_available);
        String noUpdateMsg = String.format(getResources().getString(R.string.have_latest_version), appVersion);
        Utils.showAlertDialog(this, noUpdateTitle, noUpdateMsg);
    }

    // checkUpdateAfterDelay checks to see if a newer version of Lantern is available
    // after a small delay
    private void checkUpdateAfterDelay() {

        if (UpdateActivity.active) {
            Log.d(TAG, "Update view already open! Not performing an additional check");
            return;
        }

        // disable period checks for debug builds
        // (you can still test updates from the side-menu)
        boolean isDebuggable = Utils.isDebuggable(LanternMainActivity.this);
        boolean drawerOpen = drawerLayout != null &&
            drawerLayout.isDrawerOpen(GravityCompat.START);

        // Don't check for an update if its a debug build or side-menu is open
        if (isDebuggable || drawerOpen) {
            Log.d(TAG, "Skipping update check");
            return;
        }

        final Handler updateHandler = new Handler();
        final Runnable checkUpdate = new Runnable() {
            @Override
            public void run() {
                if (!isFinishing()) {
                    checkUpdateAvailable(false);
                }
            }
        };

        // after 8s, show update popup
        updateHandler.postDelayed(checkUpdate, 8000);
    }

    // checkUpdateAvailable compares the current app version with the latest available
    // - If an update is available, we start the Update activity
    //   and prompt the user to download it
    // - If no update is available, an alert dialog is displayed
    // - userClicked is a boolean used to indicate whether the udpate was triggered from
    //   the side-menu or is an automatic check
    private void checkUpdateAvailable(boolean userClicked) {

        Log.d(TAG, String.format("Currently running %s; seeing if a new version is available", appVersion));

        String url;

        boolean isPlayVersion = Utils.isPlayVersion(LanternMainActivity.this);
        if (isPlayVersion) {
            // If the user installed the app via Google Play, we just open the Play store
            // because self-updating will not work:
            // "An app downloaded from Google Play may not modify, replace, or update itself 
            // using any method other than Google Play's update mechanism"
            // https://play.google.com/about/privacy-and-security.html#malicious-behavior
            if (userClicked) {
                Utils.openPlayStore(LanternMainActivity.this);
            }
            return;
        }

        try {
            url = Lantern.CheckForUpdates(session.shouldProxy());
        } catch (Exception e) {
            Log.e(TAG, "Error trying to check for updates: " + e.getMessage());
            e.printStackTrace();
            // An error occurred trying to check for a new version of Lantern
            if (userClicked) {
                Utils.showAlertDialog(this, "Lantern",
                        getResources().getString(R.string.error_checking_for_update));
            }
            return;
        }

        // No error occurred but the returned url is empty which
        // means no update is available
        if (url == null || url.equals("")) {
            noUpdateAvailable(userClicked);
            return;
        }

        // an updated version of Lantern is available at the given url
        Intent intent = new Intent(this, UpdateActivity_.class);
        intent.putExtra("updateUrl", url);
        startActivity(intent);
    }

    // showFeedview optionally fetches the feed depending on the
    // user's preference and updates the position of the on/off switch
    private void showFeedview() {
        RelativeLayout.LayoutParams lp = (RelativeLayout.LayoutParams) powerLantern.getLayoutParams();

        if (session.showFeed()) {
            feedView.setVisibility(View.VISIBLE);
            removeRule(lp, RelativeLayout.CENTER_VERTICAL);

            // now actually refresh the news feed
            new GetFeed(this).execute(session.shouldProxy());
        } else {
            feedView.setVisibility(View.INVISIBLE);
            lp.addRule(RelativeLayout.CENTER_VERTICAL);
        }
        powerLantern.setLayoutParams(lp);
    }

    // removeRule updates a relative layout to remove the given rule 
    // note: removeRule was only added in API level 17
    private void removeRule(RelativeLayout.LayoutParams lp, int rule) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) { // API 17
            lp.removeRule(rule);
        } else {
            lp.addRule(rule, 0);
        }
    }

    // updateFeedview updates the UI to show/hide the newsfeed
    public void updateFeedview(final ListAdapter listAdapter,
        final ArrayList<NavItem> navItems,
        final Resources resources,
        final boolean showFeed) {
      
        // store show/hide feed preference
        session.updateFeedPreference(showFeed);
        showFeedview();

        for (NavItem item: navItems) {
            if (item != null && item.newsFeedItem(resources)) {
                if (showFeed) {
                    item.setTitle(resources.getString(R.string.newsfeed_off_option));
                } else {
                    item.setTitle(resources.getString(R.string.newsfeed_option));
                }
                break;
            }
        }

        if (listAdapter != null) {
            listAdapter.notifyDataSetChanged();
        }
    }

    private void updateStatus(boolean useVpn) {
        displayStatus(useVpn);
        updateTheme(useVpn);
        session.updateVpnPreference(useVpn);
    }

    private void updateTheme(boolean useVpn) {
        powerLantern.setThumbColorRes(useVpn ? R.color.accent_white : R.color.accent_white);
        powerLantern.setBackColorRes(useVpn ? R.color.on_color : R.color.pro_blue_color );
        changeFeedHeaderColor(useVpn);
    }

    @Click(R.id.powerLantern)
    public void switchLantern(View view) {

        boolean on = ((SwitchButton)view).isChecked();

        if (!Utils.isNetworkAvailable(getApplicationContext())) {
            powerLantern.setChecked(false);
            if (on) {
                // User tried to turn Lantern on, but there's no 
                // Internet connection available.
                Utils.showAlertDialog(this, "Lantern", 
                        getResources().getString(R.string.no_internet_connection));
            } 
            return;
        }

        // disable the on/off switch while the VpnService
        // is updating the connection
        powerLantern.setEnabled(false);

        if (on) {
            // Prompt the user to enable full-device VPN mode
            // Make a VPN connection from the client
            // We should only have one active VPN connection per client
            try {
                Log.d(TAG, "Load VPN configuration");
                Intent intent = VpnService.prepare(getApplicationContext());
                if (intent != null) {
                    Log.w(TAG,"Requesting VPN connection");
                    startActivityForResult(intent, REQUEST_VPN);
                } else {
                    Log.d(TAG, "VPN enabled, starting Lantern...");
                    updateStatus(true);
                    org.lantern.mobilesdk.Lantern.disable(getApplicationContext());
                    sendIntentToService();
                }    
            } catch (Exception e) {
                Log.e(TAG, "Could not establish VPN connection: " + e.getMessage());
                powerLantern.setChecked(false);
            }
        } else  {
            Service.IsRunning = false;
            updateStatus(false);
        }

        // after 2000ms, enable the switch again
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                powerLantern.setEnabled(true);
            }
        }, 2000);
    }

    // override onKeyDown and onBackPressed default 
    // behavior to prevent back button from interfering 
    // with on/off switch
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event)  {
        if (Integer.parseInt(android.os.Build.VERSION.SDK) > 5
                && keyCode == KeyEvent.KEYCODE_BACK
                && event.getRepeatCount() == 0) {
            Log.d(TAG, "onKeyDown Called");
            onBackPressed();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public void onBackPressed() {
        Log.d(TAG, "onBackPressed Called");
        Intent setIntent = new Intent(Intent.ACTION_MAIN);
        setIntent.addCategory(Intent.CATEGORY_HOME);
        setIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(setIntent);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        getApplication().unregisterActivityLifecycleCallbacks(this);
        try {
            if (mReceiver != null) {
                unregisterReceiver(mReceiver);
            }
        } catch (Exception e) {

        }
    }

    // quitLantern is the side menu option and cleanyl exits the app
    public void quitLantern() {
        try {
            Log.d(TAG, "About to exit Lantern...");

            session.updateVpnPreference(false);
            Service.IsRunning = false;

            // sleep for a few ms before exiting
            Thread.sleep(200);

            finish();
            moveTaskToBack(true);

        } catch (Exception e) {
            Log.e(TAG, "Got an exception when quitting Lantern " + e.getMessage());
        }
    }

    // opens an e-mail message with some default options
    private void contactOption() {

        String contactEmail = getResources().getString(R.string.contact_email);
        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType("plain/text");
        intent.putExtra(Intent.EXTRA_EMAIL, new String[] { contactEmail });
        intent.putExtra(Intent.EXTRA_SUBJECT, R.string.contact_subject);
        intent.putExtra(Intent.EXTRA_TEXT, R.string.contact_message);

        startActivity(Intent.createChooser(intent, ""));
    }


    public void refreshFeed(View view) {
        Log.d(TAG, "Refresh feed clicked");
        feedError.setVisibility(View.INVISIBLE);
        if (session.showFeed()) {
            new GetFeed(this).execute(session.shouldProxy());
        }
    }

    public void showFeedError() {
        feedError.setVisibility(View.VISIBLE);
    }

    public void openFeedItem(View view) {

        TextView url = (TextView)view.findViewById(R.id.link);
        Log.d(TAG, "Feed item clicked: " + url.getText());

        if (lastFeedSelected != null) {
            // whenever a user clicks on an article, send a custom event to GA 
            // that includes the source/feed category
            Utils.sendFeedEvent(getApplicationContext(),
                    String.format("feed-%s", lastFeedSelected));
        }

        new FinestWebView.Builder(this)
            .webViewSupportMultipleWindows(true)
            .webViewJavaScriptEnabled(true)
            .swipeRefreshColorRes(R.color.black)
            .webViewAllowFileAccessFromFileURLs(true)
            .webViewJavaScriptCanOpenWindowsAutomatically(true)
            .webViewLoadWithProxy(session.startLocalProxy())
            // if we aren't in full-device VPN mode, configure the 
            // WebView to use our local proxy
            .show(url.getText().toString());
    }

    public void shareFeedItem(View child) {
        ViewGroup view = (ViewGroup) child.getParent().getParent();
        TextView url = (TextView)view.findViewById(R.id.link);
        Log.d(TAG, "Share feed item clicked: " + url.getText());
       
        TextView title = (TextView)view.findViewById(R.id.title);
        if (title.getText() != null) {
            String shareMsg = String.format(getResources().getString(R.string.share_feed_item), title.getText().toString(), url.getText().toString());
            Log.d(TAG, "Share button pressed. Share message is " + shareMsg);

            Intent sendIntent = new Intent(Intent.ACTION_VIEW);
            sendIntent.setData(Uri.parse("sms:"));
            sendIntent.putExtra("sms_body", shareMsg);
            startActivity(sendIntent);
        }
    }

    public void changeFeedHeaderColor(boolean useVpn) {
        if (feedAdapter != null && viewPagerTab != null) {
            int c;
            if (useVpn) {
                c = getResources().getColor(R.color.accent_white); 
            } else {
                c = getResources().getColor(R.color.black); 
            }
            int count = feedAdapter.getCount();
            for (int i = 0; i < count; i++) {
                TextView view = (TextView) viewPagerTab.getTabAt(i);
                view.setTextColor(c);
            }
        }
    }

    public void setupFeed(final ArrayList<String> sources) {

        final FragmentPagerItems.Creator c = FragmentPagerItems.with(this);

        if (sources != null && !sources.isEmpty()) {
            String all = getResources().getString(R.string.all_feeds);
            sources.add(0, all);

            for (String source : sources) {
                Log.d(TAG, "Adding source: " + source);
                Bundle bundle = new Bundle();
                bundle.putString("name", source);
                c.add(source, FeedFragment.class, bundle);
            }
        } else {
            // if we get back zero sources, some issue occurred
            // downloading and/or parsing the feed
            showFeedError();
            return;
        }

        feedAdapter = new FragmentStatePagerItemAdapter(
                this.getSupportFragmentManager(), c.create());

        ViewPager viewPager = (ViewPager)this.findViewById(R.id.viewpager);
        viewPager.setAdapter(feedAdapter);

        viewPagerTab = (SmartTabLayout)this.findViewById(R.id.viewpagertab);
        viewPagerTab.setViewPager(viewPager);

        viewPagerTab.setOnPageChangeListener(new ViewPager.SimpleOnPageChangeListener() {
            @Override
            public void onPageSelected(int position) {
                super.onPageSelected(position);
                Fragment f = feedAdapter.getPage(position);
                if (f instanceof FeedFragment) {
                    lastFeedSelected = ((FeedFragment)f).getFeedName();
                }
            }
        });

        View tab = viewPagerTab.getTabAt(0);
        if (tab != null) {
            tab.setSelected(true);
        }

        changeFeedHeaderColor(Service.IsRunning);
    }

    @Override
    protected void onActivityResult(int request, int response, Intent data) {
        super.onActivityResult(request, response, data);
        if (request == REQUEST_VPN) {
            boolean useVpn = response == RESULT_OK;
            updateStatus(useVpn);
            if (useVpn) {
                org.lantern.mobilesdk.Lantern.disable(getApplicationContext());
                sendIntentToService();
            }
        }
    }

    private void sendIntentToService() {
        startService(new Intent(this, Service.class));
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

    // LanternReceiver is used to capture broadcasts 
    // such as network connectivity and when the app
    // is powered off
    public class LanternReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();

            if (isInitialStickyBroadcast()) {
                // We only want to handle connectivity changes
                // so ignore the initial sticky broadcast for 
                // NETWORK_STATE_CHANGED_ACTION.
                return;
            }

            if (action.equals(Intent.ACTION_SHUTDOWN)) {
                // whenever the device is powered off or the app
                // abruptly closed, we want to clear user preferences
                Utils.clearPreferences(context);
            } else if (action.equals(ConnectivityManager.CONNECTIVITY_ACTION)) {
                NetworkInfo networkInfo =
                    intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK_INFO);

                if (networkInfo.getType() == ConnectivityManager.TYPE_WIFI) {
                    if (networkInfo.isConnected()) {
                        // automatically refresh feed when connectivity is detected
                        refreshFeed(null);
                    } else {
                        if (session.useVpn()) {
                            // whenever a user disconnects from Wifi and Lantern is running
                            updateStatus(false);
                            org.lantern.mobilesdk.Lantern.disable(getApplicationContext());
                            powerLantern.setChecked(false);
                            Service.IsRunning = false;
                        }
                    }
                }
            }
        }
    }

    public void onActivityResumed(Activity activity) { 
        // we only want to refresh the public feed whenever the
        // app returns to the foreground instead of every
        // time the main activity is resumed
        if (isInBackground) {
            Log.d(TAG, "App in foreground");
            isInBackground = false;
            refreshFeed(null);
            checkUpdateAfterDelay();
        }
    }

    // Below unused
    public void onActivityCreated(Activity activity, Bundle savedInstanceState) {}

    public void onActivityDestroyed(Activity activity) {}

    public void onActivityPaused(Activity activity) {}

    public void onActivitySaveInstanceState(Activity activity, Bundle outState) {}

    public void onActivityStarted(Activity activity) {}

    public void onActivityStopped(Activity activity) {}

    @Override
    public void onTrimMemory(int i) {
        // this lets us know when the app process is no longer showing a user
        // interface, i.e. when the app went into the background
        if (i == ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            Log.d(TAG, "App went to background");
            isInBackground = true;
        }
    }

}
