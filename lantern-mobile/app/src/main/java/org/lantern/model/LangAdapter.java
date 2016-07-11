package org.lantern.model;

import android.content.Context;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.TextView;

import java.util.ArrayList;       
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.lantern.R;

public class LangAdapter extends ArrayAdapter<String> {

	private static final String TAG = "LangAdapter";
	private static Map<String, Locale> localeMap;


    public LangAdapter(Context context, ArrayList<String> lang) {
       super(context, 0, lang);
    }

	public void setLocaleMap(final Map<String, Locale> localeMap) {
		this.localeMap = localeMap;
	}
    

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {

		String lang = getItem(position);
        String current = Locale.getDefault().toString();
		int color = getContext().getResources().getColor(R.color.black);
		if (localeMap != null) {
			Locale entry = localeMap.get(lang);
			if (entry != null && entry.toString().equals(current)) {
				// the current locale should be highlighted the selected color
				color = getContext().getResources().getColor(R.color.pink);
			}
		}
		
       // Check if an existing view is being reused, otherwise inflate the view
       if (convertView == null) {
          convertView = LayoutInflater.from(getContext()).inflate(R.layout.language_item, parent, false);
       }

	   TextView tv = (TextView)convertView.findViewById(R.id.title);
	   tv.setText(lang);
	   tv.setTextColor(color);
		
       // Return the completed view to render on screen
       return convertView;
   }
}
