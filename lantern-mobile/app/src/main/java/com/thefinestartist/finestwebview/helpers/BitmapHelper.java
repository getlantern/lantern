package com.thefinestartist.finestwebview.helpers;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.support.annotation.ColorInt;

/**
 * Created by Leonardo on 11/21/15.
 */
public class BitmapHelper {

    public static Bitmap getGradientBitmap(int width, int height, @ColorInt int color) {
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

        int alpha = Color.alpha(color);
        int red = Color.red(color);
        int green = Color.green(color);
        int blue = Color.blue(color);

        int[] pixels = new int[width * height];
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height);
        for (int y = 0; y < height; y++) {
            int gradientAlpha = (int) ((float) alpha * (float) (height - y) * (float) (height - y) / (float) height / (float) height);
            for (int x = 0; x < width; x++) {
                pixels[x + y * width] = Color.argb(gradientAlpha, red, green, blue);
            }
        }

        bitmap.setPixels(pixels, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
        return bitmap;
    }
}
