package org.getlantern.lantern.activity;

import android.animation.ArgbEvaluator;
import android.animation.ObjectAnimator;
import android.app.Application;
import android.app.Activity;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentCallbacks2;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.TransitionDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.StrictMode;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.VpnService;
import android.net.wifi.WifiManager;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.AdapterView;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.ImageView;
import android.widget.ListView;
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
import android.support.v4.app.NotificationCompat;
import android.support.v4.view.ViewPager;
import android.support.v4.widget.DrawerLayout;

import org.getlantern.lantern.LanternApp;
import org.getlantern.lantern.vpn.Service;
import org.getlantern.lantern.fragment.FeedFragment;
import org.getlantern.lantern.model.GetFeed;
import org.getlantern.lantern.model.ListAdapter;
import org.getlantern.lantern.model.NavItem;
import org.getlantern.lantern.model.SessionManager;
import org.getlantern.lantern.model.Shareable;
import org.getlantern.lantern.model.Utils;
import org.getlantern.lantern.R;

import java.util.ArrayList; 
import java.util.Map;
import java.util.HashMap;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.Fullscreen;
import org.androidannotations.annotations.ViewById;

import com.thefinestartist.finestwebview.FinestWebView;
import com.ogaclejapan.smarttablayout.utils.v4.FragmentStatePagerItemAdapter;
import com.ogaclejapan.smarttablayout.utils.v4.FragmentPagerItems;
import com.ogaclejapan.smarttablayout.SmartTabLayout;


import org.lantern.mobilesdk.Lantern;

@Fullscreen
@EActivity(R.layout.activity_lantern_main)
public class LanternMainActivity extends AppCompatActivity implements 
Application.ActivityLifecycleCallbacks, ComponentCallbacks2, OnCheckedChangeListener {

    private static final String TAG = "LanternMainActivity";
    private static final String PREFS_NAME = "LanternPrefs";
    private final static int REQUEST_VPN = 7777;
    private SharedPreferences mPrefs = null;
    private BroadcastReceiver mReceiver;
    private Context context;

    private NotificationManager mNotifier;
    private final NotificationCompat.Builder mNotificationBuilder = new NotificationCompat.Builder(this);
    private static final int NOTIFICATION_ID = 10002;

    private Shareable shareable;

    private boolean isInBackground = false;
    private FragmentStatePagerItemAdapter feedAdapter;
    private SmartTabLayout viewPagerTab;
    private String lastFeedSelected;

    private ObjectAnimator colorFadeIn, colorFadeOut;

    private static final int onColor = Color.parseColor("#39C2D6");
    private static final int offColor = Color.parseColor("#FFFFFF"); 

    ColorDrawable[] offTransColor = {new ColorDrawable(offColor), new ColorDrawable(onColor)};
    ColorDrawable[] onTransColor = {new ColorDrawable(onColor), new ColorDrawable(offColor)};     

    private TransitionDrawable offNavTrans = new TransitionDrawable(offTransColor);
    private TransitionDrawable onNavTrans = new TransitionDrawable(onTransColor);

    private ImageView statusImage;
    private Toast statusToast;

    private SessionManager session;

    @ViewById(R.id.versionNum)
    TextView versionNum;

    @ViewById(R.id.powerLantern)
    ToggleButton powerLantern;

    @ViewById(R.id.drawerLayout)
    DrawerLayout mDrawerLayout;

    @ViewById(R.id.drawerPane)
    RelativeLayout mDrawerPane;

    @ViewById(R.id.navList)
    ListView mDrawerList;

    @ViewById
    View feedError, feedView;

    @ViewById(R.id.settings_icon)
    ImageView settingsIcon;

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


        mPrefs = Utils.getSharedPrefs(context);
        mNotifier = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        setupNotifications();

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

        // update version number that appears at the bottom of the side menu
        // if we have it stored in shared preferences; otherwise, default to absent until
        // Lantern starts
        setVersionNum();

        setupStatusToast();

        setBtnStatus();

        // START/STOP button to enable full-device VPN functionality
        powerLantern.setOnCheckedChangeListener(this);

        setupFeedView();
    }

    @Override
    protected void onResume() {
        super.onResume();

        setupSideMenu();

        //  we check if mPrefs has been initialized before
        // since onCreate and onResume are always both called
        if (mPrefs != null) {
            setBtnStatus();
        }
    }

    private void setupFeedView() {
        RelativeLayout.LayoutParams lp = (RelativeLayout.LayoutParams) powerLantern.getLayoutParams();

        if (session.showNewsFeed()) {
            feedView.setVisibility(View.VISIBLE);
            lp.removeRule(RelativeLayout.CENTER_VERTICAL);
            new GetFeed(this, session.startLocalProxy()).execute("");
        } else {
            feedView.setVisibility(View.INVISIBLE);
            lp.addRule(RelativeLayout.CENTER_VERTICAL);
        }
        powerLantern.setLayoutParams(lp);
    }

    // update START/STOP power Lantern button
    // according to our stored preference
    public void setBtnStatus() {
        boolean useVpn = session.useVpn();
        powerLantern.setChecked(useVpn);

        if (useVpn) {
            this.mDrawerLayout.setBackgroundColor(onColor);
            settingsIcon.setImageResource(R.drawable.menu_white);   
        } else {
            this.mDrawerLayout.setBackgroundColor(offColor);
            settingsIcon.setImageResource(R.drawable.menu);   
        }
    }


    interface Command {
        void runCommand();
    }

    // initialize and configure status toast (what's displayed
    // whenever we use the on/off slider) 
    public void setupStatusToast() {

        colorFadeIn = ObjectAnimator.ofObject((View)mDrawerLayout, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        colorFadeOut = ObjectAnimator.ofObject((View)mDrawerLayout, "backgroundColor", new ArgbEvaluator(), onColor, offColor);

        colorFadeIn.setDuration(500);
        colorFadeOut.setDuration(500);

        onNavTrans.startTransition(500);
        offNavTrans.startTransition(500);

        LayoutInflater inflater = getLayoutInflater();
        statusLayout = inflater.inflate(R.layout.status_layout, 
                (ViewGroup)findViewById(R.id.status_layout_root));
        statusImage = (ImageView)statusLayout.findViewById(R.id.status_image);
        statusToast = new Toast(getApplicationContext());
        statusToast.setGravity(Gravity.BOTTOM|Gravity.FILL_HORIZONTAL, 0, 0);
        statusToast.setDuration(Toast.LENGTH_SHORT);
    }

    public void toggleSwitch(boolean useVpn) {
        displayStatus(useVpn);
        // store the updated preference 
        session.updateVpnPreference(useVpn);
    }


    public void displayStatus(final boolean useVpn) {
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

    public void setVersionNum() {
        try {
            // configure actions to be taken whenever slider changes state
            PackageInfo pInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            String appVersion = pInfo.versionName;
            Log.d(TAG, "Currently running Lantern version: " + appVersion);
            // update version number that appears at the bottom of the side menu
            // if we have it stored in shared preferences; otherwise, default to absent until
            // Lantern starts
            versionNum.setText(appVersion);
        } catch (android.content.pm.PackageManager.NameNotFoundException nne) {
            Log.e(TAG, "Could not find package: " + nne.getMessage());
        }
    }

    public void setupSideMenu() {
        final LanternMainActivity activity = this;

        final Resources resources = getResources();
        
        final Map<String, Command> menuMap = new HashMap<String, Command>();


        final ArrayList<NavItem> mNavItems = new ArrayList<NavItem>() {{
            add(new NavItem(resources.getString(R.string.share_option),
                        R.drawable.ic_share));
            add(new NavItem(resources.getString(R.string.desktop_option), 
                        R.drawable.ic_desktop));
            add(new NavItem(resources.getString(R.string.contact_option), 
                        R.drawable.ic_contact));
        }};

        final ListAdapter listAdapter = new ListAdapter(this, mNavItems);  

        if (session.showNewsFeed())  {
            mNavItems.add(new NavItem(resources.getString(R.string.newsfeed_off_option), R.drawable.ic_feed));
        } else {
            mNavItems.add(new NavItem(resources.getString(R.string.newsfeed_option), R.drawable.ic_feed));
        }
        
        mNavItems.add(new NavItem(resources.getString(R.string.quit_option), 
                    R.drawable.ic_quit));

        menuMap.put(resources.getString(R.string.quit_option), new Command() { 
            public void runCommand() { quitLantern(); } 
        });

        menuMap.put(resources.getString(R.string.contact_option), new Command() { 
            public void runCommand() { contactOption(); } 
        });

        menuMap.put(resources.getString(R.string.newsfeed_off_option), new Command() {
            public void runCommand() { 
                updateFeedview(listAdapter, mNavItems, resources, 3, false);
            }
        });

        menuMap.put(resources.getString(R.string.newsfeed_option), new Command() {
            public void runCommand() { 
                updateFeedview(listAdapter, mNavItems, resources, 3, true);
            }
        });

        menuMap.put(resources.getString(R.string.desktop_option), new Command() { 
            public void runCommand() { 
                startActivity(new Intent(activity, DesktopActivity_.class));
            } 
        });

        menuMap.put(resources.getString(R.string.share_option), new Command() { 
            public void runCommand() { shareable.showOption(); } 
        });   

        // Populate the Navigtion Drawer with options
        mDrawerList.setAdapter(listAdapter);

        // remove ListView border
        mDrawerList.setDivider(null);

        // Drawer Item click listeners
        mDrawerList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {

                mDrawerList.setItemChecked(position, true);
                String title = mNavItems.get(position).getTitle();
                Log.d(TAG, "Menu option " + title + " selected");

                menuMap.get(title).runCommand();

                // Close the drawer
                mDrawerLayout.closeDrawer(mDrawerPane);
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


        settingsIcon.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                mDrawerLayout.openDrawer(Gravity.START);
                Log.v(TAG, " click");         
            }        
        });

        mDrawerLayout.setDrawerListener(mDrawerToggle);
    }

    public void updateFeedview(final ListAdapter listAdapter,
        final ArrayList<NavItem> mNavItems,
        final Resources resources,
        int menuOptionIndex, boolean showFeed) {
      
        session.updateNewsfeedPreference(showFeed);
        setupFeedView();
        if (showFeed) {
            mNavItems.get(menuOptionIndex).setTitle(resources.getString(R.string.newsfeed_off_option));
        } else {
            mNavItems.get(menuOptionIndex).setTitle(resources.getString(R.string.newsfeed_option));
        }
        listAdapter.notifyDataSetChanged();
    }

    @Override
    public void onCheckedChanged(CompoundButton toggleButton, boolean isChecked) {

        final LanternMainActivity activity = this;

        if (!Utils.isNetworkAvailable(activity.getApplicationContext())) {
            powerLantern.setChecked(false);
            Utils.showAlertDialog(activity, "Lantern", 
                    getResources().getString(R.string.no_internet_connection));
            return;
        }

        // disable the on/off switch while the VpnService
        // is updating the connection
        powerLantern.setEnabled(false);

        if (isChecked) {
            enableVPN();
        } else {
            toggleSwitch(false);
            stopLantern();
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
    public void onConfigurationChanged(Configuration newConfig) {
        //don't reload the current page when the orientation is changed
        Log.d(TAG, "onConfigurationChanged() Called");
        super.onConfigurationChanged(newConfig);

        /*if (listAdapter != null) {
            listAdapter.refresh();
        }*/
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

            stopLantern();

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
        if (session.showNewsFeed()) {
            new GetFeed(this, session.startLocalProxy()).execute("");
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

    // Prompt the user to enable full-device VPN mode
    // Make a VPN connection from the client
    // We should only have one active VPN connection per client
    public void enableVPN() {
        Log.d(TAG, "Load VPN configuration");
        try {
            Intent intent = VpnService.prepare(this);
            if (intent != null) {
                Log.w(TAG,"Requesting VPN connection");
                startActivityForResult(intent, REQUEST_VPN);
            } else {
                Log.d(TAG, "VPN enabled, starting Lantern...");
                Lantern.disable(getApplicationContext());
                toggleSwitch(true);
                changeFeedHeaderColor(true);
                sendIntentToService();
            }    
        } catch (Exception e) {
            Log.e(TAG, "Could not establish VPN connection: " + e.getMessage());
        }
    }

    @Override
    protected void onActivityResult(int request, int response, Intent data) {
        super.onActivityResult(request, response, data);

        if (request == REQUEST_VPN) {
            if (response != RESULT_OK) {
                // no permission given to open
                // VPN connection; return to off state
                toggleSwitch(false);
            } else {
                Lantern.disable(getApplicationContext());
                toggleSwitch(true);
                sendIntentToService();
            }
        }
    }

    private void setupNotifications() {
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0,
                new Intent(this, LanternMainActivity.class)
                .setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP),
                0);

        mNotificationBuilder
            .setSmallIcon(R.drawable.status_on_white)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentTitle(getText(R.string.app_name))
            .setWhen(System.currentTimeMillis())
            .setContentIntent(pendingIntent)
            .setOngoing(true);
    }

    private void sendIntentToService() {
        startService(new Intent(this, Service.class));
        showStatusIcon();
    }

    public void showStatusIcon() {
        if (mNotifier != null) {
            mNotificationBuilder
                .setTicker(getText(R.string.service_connected))
                .setContentText(getText(R.string.service_connected));
            mNotifier.notify(NOTIFICATION_ID, mNotificationBuilder.build());
        }
    }

    public void stopLantern() {
        Service.IsRunning = false;
        Utils.clearPreferences(this);
        changeFeedHeaderColor(false);
        setBtnStatus();
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
                            stopLantern();
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
