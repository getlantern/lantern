package org.lantern.activity;

import android.support.v4.app.FragmentActivity;

public abstract class ProActivity extends FragmentActivity {
    public abstract void onSuccess();
    public abstract void onError();
}
