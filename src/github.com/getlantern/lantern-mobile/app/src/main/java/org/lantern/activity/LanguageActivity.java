package org.lantern.activity;

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

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale; 
import java.util.Map;
import java.util.HashMap;

import org.lantern.R;

@EActivity(R.layout.languages)
public class LanguageActivity extends ListActivity {

    private static final String TAG = "LanguageActivity";

    @ViewById(R.id.avatar)
    ImageView mBackBtn;

    private ArrayAdapter<String> adapter;
    private static ArrayList<String> languages;
	private static Map<String, Locale> localeMap;

    @AfterViews
    void afterViews() {
        languages = new ArrayList<String>();
        localeMap = new HashMap<String, Locale>();

        final Resources resources = getResources();
        final String[] locales   = resources.getStringArray(R.array.languages);
        final String[] specialLocaleCodes = resources.getStringArray(R.array.special_locale_codes);
        final String[] specialLocaleNames = resources.getStringArray(R.array.special_locale_names);

        final LocaleInfo[] preprocess = new LocaleInfo[locales.length];
        int finalSize = 0;

        for (int i = 0; i < locales.length; i++) {
            final String s = locales[i];
            final int len = s.length();
            /* language is of the form "en_US" */
            if (len == 5) {
                String language = s.substring(0, 2);
                String country = s.substring(3, 5);
                final Locale l = new Locale(language, country);

                if (finalSize == 0) {
                    preprocess[finalSize++] =
                        new LocaleInfo(toTitleCase(l.getDisplayLanguage(l)), l);
                } else {
                    if (preprocess[finalSize-1].locale.getLanguage().equals(
                                language)) {
                        preprocess[finalSize-1].label = toTitleCase(
                                getDisplayName(preprocess[finalSize-1].locale,
                                    specialLocaleCodes, specialLocaleNames));
                        preprocess[finalSize++] =
                            new LocaleInfo(toTitleCase(
                                        getDisplayName(
                                            l, specialLocaleCodes, specialLocaleNames)), l);
                    } else {
                        String displayName = toTitleCase(l.getDisplayLanguage(l));
                        preprocess[finalSize++] = new LocaleInfo(displayName, l);
                    }
                }
            } 
        }

        for (int i = 0; i < finalSize; i++) {
            languages.add(preprocess[i].getLabel());                                             
            localeMap.put(preprocess[i].getLabel(), preprocess[i].getLocale());
        }

        Collections.sort(languages);


        mBackBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "Back button pressed");
                finish();
            }
        });

        adapter = new ArrayAdapter<String>(this, R.layout.language_item, R.id.title, languages);
        setListAdapter(adapter); 
    }         

    private static String toTitleCase(String s) {
        if (s.length() == 0) {
            return s;
        }
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    public static class LocaleInfo implements Comparable<LocaleInfo> {
        static final Collator sCollator = Collator.getInstance();
        String label;
        Locale locale;
        public LocaleInfo(String label, Locale locale) {
            this.label = label;
            this.locale = locale;
        }
        public String getLabel() {
            return label;
        }
        public Locale getLocale() {
            return locale;
        }
        @Override
        public String toString() {
            return this.label;
        }
        @Override
        public int compareTo(LocaleInfo another) {
            return sCollator.compare(this.label, another.label);
        }
    }


    private static String getDisplayName(
            Locale l, String[] specialLocaleCodes, String[] specialLocaleNames) {
        String code = l.toString();
        for (int i = 0; i < specialLocaleCodes.length; i++) {
            if (specialLocaleCodes[i].equals(code)) {
                return specialLocaleNames[i];
            }
        }
        return l.getDisplayName(l);
    }

    @Override
    protected void onListItemClick(ListView list, View view, int position, long id) {
        String lang = (String)getListView().getItemAtPosition(position);
        setLocale(lang);
    }

    public void setLocale(String lang) { 
        Locale locale = localeMap.get(lang);
		Log.d(TAG, "Language selected: " + lang);
        Locale.setDefault(locale);
        Resources res = getResources(); 
        DisplayMetrics dm = res.getDisplayMetrics(); 
        Configuration conf = res.getConfiguration(); 
        conf.locale = locale; 
        getBaseContext().getResources().updateConfiguration(conf, dm); 
        Intent refresh = new Intent(this, LanternMainActivity_.class); 
        refresh.setAction("restart");
        refresh.addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION);
        startActivity(refresh); 
        finish();
    } 
}
