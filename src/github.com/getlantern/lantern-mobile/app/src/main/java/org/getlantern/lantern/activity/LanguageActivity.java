package org.getlantern.lantern.activity;

import android.app.Activity;
import android.app.ListActivity;
import android.content.Intent; 
import android.content.res.Configuration; 
import android.content.res.Resources; 
import android.os.Bundle;
import android.util.DisplayMetrics; 
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.ListView;

import java.util.ArrayList;
import java.util.Locale; 

import org.getlantern.lantern.R;

public class LanguageActivity extends ListActivity {

    private static final String TAG = "LanguageActivity";

    private ArrayAdapter<String> adapter;
    private static ArrayList<String> languages = new ArrayList<String>();

    static {
        for (Locale locale : Locale.getAvailableLocales()) {
            languages.add(locale.getDisplayName());
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.languages);

        adapter = new ArrayAdapter<String>(this, R.layout.language_item, R.id.title, languages);
        setListAdapter(adapter); 
    }

    @Override
    protected void onListItemClick(ListView list, View view, int position, long id) {
        String lang = (String)getListView().getItemAtPosition(position);
        Log.d(TAG, "You selected " + lang);
        setLocale(lang);
        
    }

    public void setLocale(String lang) { 
        Locale locale = new Locale(lang); 
        Resources res = getResources(); 
        DisplayMetrics dm = res.getDisplayMetrics(); 
        Configuration conf = res.getConfiguration(); 
        conf.locale = locale; 
        res.updateConfiguration(conf, dm); 
        Intent refresh = new Intent(this, LanguageActivity.class); 
        startActivity(refresh); 
        finish();
    } 
}
