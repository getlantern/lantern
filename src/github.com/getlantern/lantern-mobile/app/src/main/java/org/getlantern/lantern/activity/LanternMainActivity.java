package org.getlantern.lantern.activity;

import android.content.Intent;
import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.preference.PreferenceManager;
import android.animation.ArgbEvaluator;
import android.animation.ObjectAnimator;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.PorterDuff; 
import android.net.VpnService;
import android.support.v7.app.ActionBarActivity;
import android.support.v7.app.ActionBarDrawerToggle;
import android.support.v4.widget.DrawerLayout;
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

import java.util.ArrayList;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.R;
import org.getlantern.lantern.service.LanternVpn;


public class LanternMainActivity extends ActionBarActivity implements Handler.Callback {

    private static final String TAG = "LanternMainActivity";
    private static final String PREFS_NAME = "LanternPrefs";

    private static final int onColor = Color.parseColor("#39C2D6");
    private static final int offColor = Color.parseColor("#FAFBFB"); 

    private SharedPreferences mPrefs = null;

    private ToggleButton powerLantern;
    private Handler mHandler;
    private LayoutInflater inflater;
    private ObjectAnimator colorFadeIn, colorFadeOut;
    private View mainView;
    private View statusLayout;
    private ImageView statusImage;
    private Toast statusToast;


    ListView mDrawerList;
    RelativeLayout mDrawerPane;
    private ActionBarDrawerToggle mDrawerToggle;
    private DrawerLayout mDrawerLayout;

    ArrayList<NavItem> mNavItems = new ArrayList<NavItem>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getSupportActionBar().setDisplayHomeAsUpEnabled(true);

        mPrefs = getSharedPrefs(getApplicationContext());

        setContentView(R.layout.activity_lantern_main);

        // setup our side menu
        setupSideMenu();

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
        super.onDestroy();
        mPrefs.edit().remove(LanternConfig.PREF_USE_VPN).commit();
    }

    private void setupSideMenu() {
        mNavItems.add(new NavItem("Share", "", R.drawable.ic_action_share));
        mNavItems.add(new NavItem("Desktop Version", "", R.drawable.ic_action_share));
        mNavItems.add(new NavItem("Contact", "", R.drawable.ic_action_share));
        mNavItems.add(new NavItem("Privacy Policy", "", R.drawable.ic_action_share));
        mNavItems.add(new NavItem("Quitt", "", R.drawable.ic_action_share));


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
                //selectItemFromDrawer(position);
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
        // when we switch from 'off' to 'on', we use a 1 second 
        // fade to animate the background color
        colorFadeIn = ObjectAnimator.ofObject(mainView, "backgroundColor", new ArgbEvaluator(), offColor, onColor);
        colorFadeOut = ObjectAnimator.ofObject(mainView, "backgroundColor", new ArgbEvaluator(), onColor, offColor);
        colorFadeIn.setDuration(1000);
        colorFadeOut.setDuration(1000);

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
            statusImage.setImageResource(R.drawable.toast_on);
        } else {
            colorFadeOut.start();
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
        Intent intent = new Intent(LanternMainActivity.this, PromptVpnActivity.class);
        if (intent != null) {
            startActivity(intent);
        }
    }

    protected void stopLantern() {
        Log.d(TAG, "Stopping Lantern...");
        try {
            Intent service = new Intent(LanternMainActivity.this, LanternVpn.class);
            service.setAction(LanternConfig.DISABLE_VPN);
            startService(service);
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
        mDrawerToggle.syncState();
    }
}
