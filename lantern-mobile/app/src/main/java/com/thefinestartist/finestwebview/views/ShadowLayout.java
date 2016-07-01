package com.thefinestartist.finestwebview.views;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.BitmapDrawable;
import android.os.Build;
import android.support.v4.content.ContextCompat;
import android.util.AttributeSet;
import android.widget.FrameLayout;

import org.lantern.R;


/**
 * Created by Leonardo on 11/26/15.
 */

public class ShadowLayout extends FrameLayout {

    private int shadowColor;
    private float shadowSize;
    private float cornerRadius;
    private float dx;
    private float dy;

    public ShadowLayout(Context context) {
        super(context);
        setWillNotDraw(false);
        initAttributes(null);
        setPadding();
    }

    public ShadowLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
        setWillNotDraw(false);
        initAttributes(attrs);
        setPadding();
    }

    public ShadowLayout(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setWillNotDraw(false);
        initAttributes(attrs);
        setPadding();
    }

    private void initAttributes(AttributeSet attrs) {
        TypedArray attr = getContext().obtainStyledAttributes(attrs, R.styleable.ShadowLayout, 0, 0);
        if (attr == null)
            return;

        try {
            cornerRadius = attr.getDimension(R.styleable.ShadowLayout_slCornerRadius, getResources().getDimension(R.dimen.defaultMenuDropShadowCornerRadius));
            shadowSize = attr.getDimension(R.styleable.ShadowLayout_slShadowSize, getResources().getDimension(R.dimen.defaultMenuDropShadowSize));
            dx = attr.getDimension(R.styleable.ShadowLayout_slDx, 0);
            dy = attr.getDimension(R.styleable.ShadowLayout_slDy, 0);
            shadowColor = attr.getColor(R.styleable.ShadowLayout_slShadowColor, ContextCompat.getColor(getContext(), R.color.finestBlack10));
        } finally {
            attr.recycle();
        }
    }

    private void setPadding() {
        int xPadding = (int) (shadowSize + Math.abs(dx));
        int yPadding = (int) (shadowSize + Math.abs(dy));
        setPadding(xPadding, yPadding, xPadding, yPadding);
    }

    public void setShadowColor(int shadowColor) {
        this.shadowColor = shadowColor;
        invalidate();
    }

    public void setShadowSize(float shadowSize) {
        this.shadowSize = shadowSize;
        setPadding();
    }

    public void setCornerRadius(float cornerRadius) {
        this.cornerRadius = cornerRadius;
        invalidate();
    }

    public void setDx(float dx) {
        this.dx = dx;
        setPadding();
    }

    public void setDy(float dy) {
        this.dy = dy;
        setPadding();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

//        RoundRectShape rss = new RoundRectShape(new float[]{12f, 12f, 12f,
//                12f, 12f, 12f, 12f, 12f}, null, null);
//        ShapeDrawable sds = new ShapeDrawable(rss);
//        sds.setShaderFactory(new ShapeDrawable.ShaderFactory() {
//
//            @Override
//            public Shader resize(int width, int height) {
//                LinearGradient lg = new LinearGradient(0, 0, 0, height,
//                        new int[]{Color.parseColor("#e5e5e5"),
//                                Color.parseColor("#e5e5e5"),
//                                Color.parseColor("#e5e5e5"),
//                                Color.parseColor("#e5e5e5")}, new float[]{0,
//                        0.50f, 0.50f, 1}, Shader.TileMode.REPEAT);
//                return lg;
//            }
//        });
//
//        LayerDrawable ld = new LayerDrawable(new Drawable[]{sds, sds});
//        ld.setLayerInset(0, 5, 5, 0, 0); // inset the shadow so it doesn't start right at the left/top
//        ld.setLayerInset(1, 0, 0, 5, 5); // inset the top drawable so we can leave a bit of space for the shadow to use

        setBackgroundCompat(canvas.getWidth(), canvas.getHeight());
    }

    @SuppressWarnings("deprecation")
    private void setBackgroundCompat(int w, int h) {
        Bitmap bitmap = createShadowBitmap(w, h, cornerRadius, shadowSize, dx, dy, shadowColor, Color.TRANSPARENT);
//        Bitmap coloredBitmap = BitmapHelper.getColoredBitmap(getContext(), bitmap, shadowColor);
        BitmapDrawable drawable = new BitmapDrawable(getResources(), bitmap);
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.JELLY_BEAN) {
            setBackgroundDrawable(drawable);
        } else {
            setBackground(drawable);
        }
    }

    private Bitmap createShadowBitmap(int shadowWidth, int shadowHeight, float cornerRadius, float shadowSize,
                                      float dx, float dy, int shadowColor, int fillColor) {

        Bitmap output = Bitmap.createBitmap(shadowWidth, shadowHeight, Bitmap.Config.ALPHA_8);
        Canvas canvas = new Canvas(output);

        RectF shadowRect = new RectF(
                shadowSize,
                shadowSize,
                shadowWidth - shadowSize,
                shadowHeight - shadowSize);

        if (dy > 0) {
            shadowRect.top += dy;
            shadowRect.bottom -= dy;
        } else if (dy < 0) {
            shadowRect.top += Math.abs(dy);
            shadowRect.bottom -= Math.abs(dy);
        }

        if (dx > 0) {
            shadowRect.left += dx;
            shadowRect.right -= dx;
        } else if (dx < 0) {
            shadowRect.left += Math.abs(dx);
            shadowRect.right -= Math.abs(dx);
        }

        Paint shadowPaint = new Paint();
        shadowPaint.setAntiAlias(true);
        shadowPaint.setColor(fillColor);
        shadowPaint.setStyle(Paint.Style.FILL);
        shadowPaint.setShadowLayer(shadowSize, dx, dy, shadowColor);

        canvas.drawRoundRect(shadowRect, cornerRadius, cornerRadius, shadowPaint);

        return output;
    }

    @Override
    protected int getSuggestedMinimumWidth() {
        return 0;
    }

    @Override
    protected int getSuggestedMinimumHeight() {
        return 0;
    }

}
