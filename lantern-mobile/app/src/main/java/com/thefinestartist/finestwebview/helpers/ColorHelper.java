package com.thefinestartist.finestwebview.helpers;

import android.graphics.Color;

/**
 * Created by Leonardo on 11/28/15.
 */
public class ColorHelper {

    public static int disableColor(int color) {
        int alpha = Color.alpha(color);
        int red = Color.red(color);
        int green = Color.green(color);
        int blue = Color.blue(color);

        return Color.argb((int) (alpha * 0.2f), red, green, blue);
    }
}
