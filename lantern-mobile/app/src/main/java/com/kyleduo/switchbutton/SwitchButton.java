package com.kyleduo.switchbutton;

import android.animation.ObjectAnimator;
import android.content.Context;
import android.content.res.ColorStateList;
import android.content.res.Resources;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PointF;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Parcel;
import android.os.Parcelable;
import android.support.v4.content.ContextCompat;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.TextUtils;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.SoundEffectConstants;
import android.view.ViewConfiguration;
import android.view.ViewParent;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.CompoundButton;

import org.lantern.R;


/**
 * SwitchButton
 *
 * @author kyleduo
 * @since 2014-09-24
 */

public class SwitchButton extends CompoundButton {
	public static final float DEFAULT_BACK_MEASURE_RATIO = 1.8f;
	public static final int DEFAULT_THUMB_SIZE_DP = 20;
	public static final int DEFAULT_THUMB_MARGIN_DP = 2;
	public static final int DEFAULT_TEXT_MARGIN_DP = 2;
	public static final int DEFAULT_ANIMATION_DURATION = 250;
	public static final int DEFAULT_TINT_COLOR = 0x327FC2;

	private static int[] CHECKED_PRESSED_STATE = new int[]{android.R.attr.state_checked, android.R.attr.state_enabled, android.R.attr.state_pressed};
	private static int[] UNCHECKED_PRESSED_STATE = new int[]{-android.R.attr.state_checked, android.R.attr.state_enabled, android.R.attr.state_pressed};

	private Drawable mThumbDrawable, mBackDrawable;
	private ColorStateList mBackColor, mThumbColor;
	private float mThumbRadius, mBackRadius;
	private RectF mThumbMargin;
	private float mBackMeasureRatio;
	private long mAnimationDuration;
	// fade back drawable or color when dragging or animating
	private boolean mFadeBack;
	private int mTintColor;
	private PointF mThumbSizeF;

	private int mCurrThumbColor, mCurrBackColor, mNextBackColor, mOnTextColor, mOffTextColor;
	private Drawable mCurrentBackDrawable, mNextBackDrawable;
	private RectF mThumbRectF, mBackRectF, mSafeRectF, mTextOnRectF, mTextOffRectF;
	private Paint mPaint;
	// whether using Drawable for thumb or back
	private boolean mIsThumbUseDrawable, mIsBackUseDrawable;
	private boolean mDrawDebugRect = false;
	private ObjectAnimator mProcessAnimator;
	// animation control
	private float mProcess;
	// temp position of thumb when dragging or animating
	private RectF mPresentThumbRectF;
	private float mStartX, mStartY, mLastX;
	private int mTouchSlop;
	private int mClickTimeout;
	private Paint mRectPaint;
	private CharSequence mTextOn;
	private CharSequence mTextOff;
	private TextPaint mTextPaint;
	private Layout mOnLayout;
	private Layout mOffLayout;
	private float mTextWidth;
	private float mTextHeight;
	private float mTextMarginH;

	public SwitchButton(Context context, AttributeSet attrs, int defStyle) {
		super(context, attrs, defStyle);
		init(attrs);
	}

	public SwitchButton(Context context, AttributeSet attrs) {
		super(context, attrs);
		init(attrs);
	}

	public SwitchButton(Context context) {
		super(context);
		init(null);
	}

	private void init(AttributeSet attrs) {
		mTouchSlop = ViewConfiguration.get(getContext()).getScaledTouchSlop();
		mClickTimeout = ViewConfiguration.getPressedStateDuration() + ViewConfiguration.getTapTimeout();

		mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
		mRectPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
		mRectPaint.setStyle(Paint.Style.STROKE);
		mRectPaint.setStrokeWidth(getResources().getDisplayMetrics().density);

		mTextPaint = getPaint();

		mThumbRectF = new RectF();
		mBackRectF = new RectF();
		mSafeRectF = new RectF();
		mThumbSizeF = new PointF();
		mThumbMargin = new RectF();
		mTextOnRectF = new RectF();
		mTextOffRectF = new RectF();

		mProcessAnimator = ObjectAnimator.ofFloat(this, "process", 0, 0).setDuration(DEFAULT_ANIMATION_DURATION);
		mProcessAnimator.setInterpolator(new AccelerateDecelerateInterpolator());

		mPresentThumbRectF = new RectF();

		Resources res = getResources();
		float density = res.getDisplayMetrics().density;

		Drawable thumbDrawable = null;
		ColorStateList thumbColor = null;
		float margin = density * DEFAULT_THUMB_MARGIN_DP;
		float marginLeft = 0;
		float marginRight = 0;
		float marginTop = 0;
		float marginBottom = 0;
		float thumbWidth = density * DEFAULT_THUMB_SIZE_DP;
		float thumbHeight = density * DEFAULT_THUMB_SIZE_DP;
		float thumbRadius = density * DEFAULT_THUMB_SIZE_DP / 2;
		float backRadius = thumbRadius;
		Drawable backDrawable = null;
		ColorStateList backColor = null;
		float backMeasureRatio = DEFAULT_BACK_MEASURE_RATIO;
		int animationDuration = DEFAULT_ANIMATION_DURATION;
		boolean fadeBack = true;
		int tintColor = Integer.MIN_VALUE;
		String textOn = null;
		String textOff = null;
		float textMarginH = density * DEFAULT_TEXT_MARGIN_DP;

		TypedArray ta = attrs == null ? null : getContext().obtainStyledAttributes(attrs, R.styleable.SwitchButton);
		if (ta != null) {
			thumbDrawable = ta.getDrawable(R.styleable.SwitchButton_kswThumbDrawable);
			thumbColor = ta.getColorStateList(R.styleable.SwitchButton_kswThumbColor);
			margin = ta.getDimension(R.styleable.SwitchButton_kswThumbMargin, margin);
			marginLeft = ta.getDimension(R.styleable.SwitchButton_kswThumbMarginLeft, margin);
			marginRight = ta.getDimension(R.styleable.SwitchButton_kswThumbMarginRight, margin);
			marginTop = ta.getDimension(R.styleable.SwitchButton_kswThumbMarginTop, margin);
			marginBottom = ta.getDimension(R.styleable.SwitchButton_kswThumbMarginBottom, margin);
			thumbWidth = ta.getDimension(R.styleable.SwitchButton_kswThumbWidth, thumbWidth);
			thumbHeight = ta.getDimension(R.styleable.SwitchButton_kswThumbHeight, thumbHeight);
			thumbRadius = ta.getDimension(R.styleable.SwitchButton_kswThumbRadius, Math.min(thumbWidth, thumbHeight) / 2.f);
			backRadius = ta.getDimension(R.styleable.SwitchButton_kswBackRadius, thumbRadius + density * 2f);
			backDrawable = ta.getDrawable(R.styleable.SwitchButton_kswBackDrawable);
			backColor = ta.getColorStateList(R.styleable.SwitchButton_kswBackColor);
			backMeasureRatio = ta.getFloat(R.styleable.SwitchButton_kswBackMeasureRatio, backMeasureRatio);
			animationDuration = ta.getInteger(R.styleable.SwitchButton_kswAnimationDuration, animationDuration);
			fadeBack = ta.getBoolean(R.styleable.SwitchButton_kswFadeBack, true);
			tintColor = ta.getColor(R.styleable.SwitchButton_kswTintColor, tintColor);
			textOn = ta.getString(R.styleable.SwitchButton_kswTextOn);
			textOff = ta.getString(R.styleable.SwitchButton_kswTextOff);
			textMarginH = ta.getDimension(R.styleable.SwitchButton_kswTextMarginH, textMarginH);
			ta.recycle();
		}

		// text
		mTextOn = textOn;
		mTextOff = textOff;
		mTextMarginH = textMarginH;

		// thumb drawable and color
		mThumbDrawable = thumbDrawable;
		mThumbColor = thumbColor;
		mIsThumbUseDrawable = mThumbDrawable != null;
		mTintColor = tintColor;
		if (mTintColor == Integer.MIN_VALUE) {
			mTintColor = DEFAULT_TINT_COLOR;
		}
		if (!mIsThumbUseDrawable && mThumbColor == null) {
			mThumbColor = ColorUtils.generateThumbColorWithTintColor(mTintColor);
			mCurrThumbColor = mThumbColor.getDefaultColor();
		}
		if (mIsThumbUseDrawable) {
			thumbWidth = Math.max(thumbWidth, mThumbDrawable.getMinimumWidth());
			thumbHeight = Math.max(thumbHeight, mThumbDrawable.getMinimumHeight());
		}
		mThumbSizeF.set(thumbWidth, thumbHeight);

		// back drawable and color
		mBackDrawable = backDrawable;
		mBackColor = backColor;
		mIsBackUseDrawable = mBackDrawable != null;
		if (!mIsBackUseDrawable && mBackColor == null) {
			mBackColor = ColorUtils.generateBackColorWithTintColor(mTintColor);
			mCurrBackColor = mBackColor.getDefaultColor();
			mNextBackColor = mBackColor.getColorForState(CHECKED_PRESSED_STATE, mCurrBackColor);
		}

		// margin
		mThumbMargin.set(marginLeft, marginTop, marginRight, marginBottom);

		// size & measure params must larger than 1
		mBackMeasureRatio = mThumbMargin.width() >= 0 ? Math.max(backMeasureRatio, 1) : backMeasureRatio;

		mThumbRadius = thumbRadius;
		mBackRadius = backRadius;
		mAnimationDuration = animationDuration;
		mFadeBack = fadeBack;

		mProcessAnimator.setDuration(mAnimationDuration);

		setFocusable(true);
		setClickable(true);

		// sync checked status
		if (isChecked()) {
			setProcess(1);
		}
	}


	private Layout makeLayout(CharSequence text) {
		return new StaticLayout(text, mTextPaint, (int) Math.ceil(Layout.getDesiredWidth(text, mTextPaint)), Layout.Alignment.ALIGN_CENTER, 1.f, 0, false);
	}

	@Override
	protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
		if (mOnLayout == null && mTextOn != null) {
			mOnLayout = makeLayout(mTextOn);
		}
		if (mOffLayout == null && mTextOff != null) {
			mOffLayout = makeLayout(mTextOff);
		}
		setMeasuredDimension(measureWidth(widthMeasureSpec), measureHeight(heightMeasureSpec));
	}

	private int measureWidth(int widthMeasureSpec) {
		int widthSize = MeasureSpec.getSize(widthMeasureSpec);
		int widthMode = MeasureSpec.getMode(widthMeasureSpec);
		int measuredWidth;

		int minWidth = (int) (mThumbSizeF.x * mBackMeasureRatio);
		if (mIsBackUseDrawable) {
			minWidth = Math.max(minWidth, mBackDrawable.getMinimumWidth());
		}
		float onWidth = mOnLayout != null ? mOnLayout.getWidth() : 0;
		float offWidth = mOffLayout != null ? mOffLayout.getWidth() : 0;
		if (onWidth != 0 || offWidth != 0) {
			mTextWidth = Math.max(onWidth, offWidth) + mTextMarginH * 2;
			float left = minWidth - mThumbSizeF.x;
			if (left < mTextWidth) {
				minWidth += mTextWidth - left;
			}
		}
		minWidth = Math.max(minWidth, (int) (minWidth + mThumbMargin.left + mThumbMargin.right));
		minWidth = Math.max(minWidth, minWidth + getPaddingLeft() + getPaddingRight());
		minWidth = Math.max(minWidth, getSuggestedMinimumWidth());

		if (widthMode == MeasureSpec.EXACTLY) {
			measuredWidth = Math.max(minWidth, widthSize);
		} else {
			measuredWidth = minWidth;
			if (widthMode == MeasureSpec.AT_MOST) {
				measuredWidth = Math.min(measuredWidth, widthSize);
			}
		}

		return measuredWidth;
	}

	private int measureHeight(int heightMeasureSpec) {
		int heightMode = MeasureSpec.getMode(heightMeasureSpec);
		int heightSize = MeasureSpec.getSize(heightMeasureSpec);
		int measuredHeight;

		int minHeight = (int) Math.max(mThumbSizeF.y, mThumbSizeF.y + mThumbMargin.top + mThumbMargin.right);
		float onHeight = mOnLayout != null ? mOnLayout.getHeight() : 0;
		float offHeight = mOffLayout != null ? mOffLayout.getHeight() : 0;
		if (onHeight != 0 || offHeight != 0) {
			mTextHeight = Math.max(onHeight, offHeight);
			minHeight = (int) Math.max(minHeight, mTextHeight);
		}
		minHeight = Math.max(minHeight, getSuggestedMinimumHeight());
		minHeight = Math.max(minHeight, minHeight + getPaddingTop() + getPaddingBottom());

		if (heightMode == MeasureSpec.EXACTLY) {
			measuredHeight = Math.max(minHeight, heightSize);
		} else {
			measuredHeight = minHeight;
			if (heightMode == MeasureSpec.AT_MOST) {
				measuredHeight = Math.min(measuredHeight, heightSize);
			}
		}

		return measuredHeight;
	}

	@Override
	protected void onSizeChanged(int w, int h, int oldw, int oldh) {
		super.onSizeChanged(w, h, oldw, oldh);
		if (w != oldw || h != oldh) {
			setup();
		}
	}

	/**
	 * set up the rect of back and thumb
	 */
	private void setup() {
		float thumbTop = getPaddingTop() + Math.max(0, mThumbMargin.top);
		float thumbLeft = getPaddingLeft() + Math.max(0, mThumbMargin.left);

		if (mOnLayout != null && mOffLayout != null) {
			if (mThumbMargin.top + mThumbMargin.bottom > 0) {
				// back is higher than thumb
				float addition = (getMeasuredHeight() - getPaddingBottom() - getPaddingTop() - mThumbSizeF.y - mThumbMargin.top - mThumbMargin.bottom) / 2;
				thumbTop += addition;
			}
		}

		if (mIsThumbUseDrawable) {
			mThumbSizeF.x = Math.max(mThumbSizeF.x, mThumbDrawable.getMinimumWidth());
			mThumbSizeF.y = Math.max(mThumbSizeF.y, mThumbDrawable.getMinimumHeight());
		}

		mThumbRectF.set(thumbLeft, thumbTop, thumbLeft + mThumbSizeF.x, thumbTop + mThumbSizeF.y);

		float backLeft = mThumbRectF.left - mThumbMargin.left;
		float textDiffWidth = Math.min(0, (Math.max(mThumbSizeF.x * mBackMeasureRatio, mThumbSizeF.x + mTextWidth) - mThumbRectF.width() - mTextWidth) / 2);
		float textDiffHeight = Math.min(0, (mThumbRectF.height() + mThumbMargin.top + mThumbMargin.bottom - mTextHeight) / 2);
		mBackRectF.set(backLeft + textDiffWidth,
				mThumbRectF.top - mThumbMargin.top + textDiffHeight,
				backLeft + mThumbMargin.left + Math.max(mThumbSizeF.x * mBackMeasureRatio, mThumbSizeF.x + mTextWidth) + mThumbMargin.right - textDiffWidth,
				mThumbRectF.bottom + mThumbMargin.bottom - textDiffHeight);

		mSafeRectF.set(mThumbRectF.left, 0, mBackRectF.right - mThumbMargin.right - mThumbRectF.width(), 0);

		float minBackRadius = Math.min(mBackRectF.width(), mBackRectF.height()) / 2.f;
		mBackRadius = Math.min(minBackRadius, mBackRadius);

		if (mBackDrawable != null) {
			mBackDrawable.setBounds((int) mBackRectF.left, (int) mBackRectF.top, (int) mBackRectF.right, (int) mBackRectF.bottom);
		}

		if (mOnLayout != null) {
			float marginOnX = mBackRectF.left + (mBackRectF.width() - mThumbRectF.width() - mOnLayout.getWidth()) / 2 - mThumbMargin.left + mTextMarginH * (mThumbMargin.left > 0 ? 1 : -1);
			float marginOnY = mBackRectF.top + (mBackRectF.height() - mOnLayout.getHeight()) / 2;
			mTextOnRectF.set(marginOnX, marginOnY, marginOnX + mOnLayout.getWidth(), marginOnY + mOnLayout.getHeight());
		}

		if (mOffLayout != null) {
			float marginOffX = mBackRectF.right - (mBackRectF.width() - mThumbRectF.width() - mOffLayout.getWidth()) / 2 + mThumbMargin.right - mOffLayout.getWidth() - mTextMarginH * (mThumbMargin.right > 0 ? 1 : -1);
			float marginOffY = mBackRectF.top + (mBackRectF.height() - mOffLayout.getHeight()) / 2;
			mTextOffRectF.set(marginOffX, marginOffY, marginOffX + mOffLayout.getWidth(), marginOffY + mOffLayout.getHeight());
		}
	}

	@Override
	protected void onDraw(Canvas canvas) {
		super.onDraw(canvas);

		// fade back
		if (mIsBackUseDrawable) {
			if (mFadeBack && mCurrentBackDrawable != null && mNextBackDrawable != null) {
				int alpha = (int) (255 * (isChecked() ? getProcess() : (1 - getProcess())));
				mCurrentBackDrawable.setAlpha(alpha);
				mCurrentBackDrawable.draw(canvas);
				alpha = 255 - alpha;
				mNextBackDrawable.setAlpha(alpha);
				mNextBackDrawable.draw(canvas);
			} else {
				mBackDrawable.setAlpha(255);
				mBackDrawable.draw(canvas);
			}
		} else {
			if (mFadeBack) {
				int alpha;
				int colorAlpha;

                mPaint.setStyle(Paint.Style.FILL);
				// curr back
				alpha = (int) (255 * (isChecked() ? getProcess() : (1 - getProcess())));
				colorAlpha = Color.alpha(mCurrBackColor);
				colorAlpha = colorAlpha * alpha / 255;
				mPaint.setARGB(colorAlpha, Color.red(mCurrBackColor), Color.green(mCurrBackColor), Color.blue(mCurrBackColor));
				canvas.drawRoundRect(mBackRectF, mBackRadius, mBackRadius, mPaint);

				// next back
				alpha = 255 - alpha;
				colorAlpha = Color.alpha(mNextBackColor);
				colorAlpha = colorAlpha * alpha / 255;
				mPaint.setARGB(colorAlpha, Color.red(mNextBackColor), Color.green(mNextBackColor), Color.blue(mNextBackColor));
				canvas.drawRoundRect(mBackRectF, mBackRadius, mBackRadius, mPaint);

				mPaint.setAlpha(255);
			} else {
				mPaint.setColor(mCurrBackColor);
				canvas.drawRoundRect(mBackRectF, mBackRadius, mBackRadius, mPaint);
			}
		}

		// text
		Layout switchText = getProcess() > 0.5 ? mOnLayout : mOffLayout;
		RectF textRectF = getProcess() > 0.5 ? mTextOnRectF : mTextOffRectF;
		if (switchText != null && textRectF != null) {
			int alpha = (int) (255 * (getProcess() >= 0.75 ? getProcess() * 4 - 3 : (getProcess() < 0.25 ? 1 - getProcess() * 4 : 0)));
			int textColor = getProcess() > 0.5 ? mOnTextColor : mOffTextColor;
			int colorAlpha = Color.alpha(textColor);
			colorAlpha = colorAlpha * alpha / 255;
			switchText.getPaint().setARGB(colorAlpha, Color.red(textColor), Color.green(textColor), Color.blue(textColor));
			canvas.save();
			canvas.translate(textRectF.left, textRectF.top);
			switchText.draw(canvas);
			canvas.restore();
		}

		// thumb
		mPresentThumbRectF.set(mThumbRectF);
		mPresentThumbRectF.offset(mProcess * mSafeRectF.width(), 0);
		if (mIsThumbUseDrawable) {
			mThumbDrawable.setBounds((int) mPresentThumbRectF.left, (int) mPresentThumbRectF.top, (int) mPresentThumbRectF.right, (int) mPresentThumbRectF.bottom);
			mThumbDrawable.draw(canvas);
		} else {
            // border
            mPaint.setStyle(Paint.Style.STROKE);
            mPaint.setColor(Color.BLACK);
            mPaint.setStrokeWidth(5);
            canvas.drawRoundRect(mPresentThumbRectF, mThumbRadius, mThumbRadius, mPaint);

            mPaint.setStyle(Paint.Style.FILL);
            mPaint.setColor(mCurrThumbColor);
            canvas.drawRoundRect(mPresentThumbRectF, mThumbRadius, mThumbRadius, mPaint);
		}

		if (mDrawDebugRect) {
			mRectPaint.setColor(Color.parseColor("#AA0000"));
			canvas.drawRect(mBackRectF, mRectPaint);
			mRectPaint.setColor(Color.parseColor("#0000FF"));
			canvas.drawRect(mPresentThumbRectF, mRectPaint);
			mRectPaint.setColor(Color.parseColor("#00CC00"));
			canvas.drawRect(getProcess() > 0.5 ? mTextOnRectF : mTextOffRectF, mRectPaint);
		}
	}

	@Override
	protected void drawableStateChanged() {
		super.drawableStateChanged();

		if (!mIsThumbUseDrawable && mThumbColor != null) {
			mCurrThumbColor = mThumbColor.getColorForState(getDrawableState(), mCurrThumbColor);
		} else {
			setDrawableState(mThumbDrawable);
		}

		int[] nextState = isChecked() ? UNCHECKED_PRESSED_STATE : CHECKED_PRESSED_STATE;
		ColorStateList textColors = getTextColors();
		if (textColors != null) {
			int defaultTextColor = textColors.getDefaultColor();
			mOnTextColor = textColors.getColorForState(CHECKED_PRESSED_STATE, defaultTextColor);
			mOffTextColor = textColors.getColorForState(UNCHECKED_PRESSED_STATE, defaultTextColor);
		}
		if (!mIsBackUseDrawable && mBackColor != null) {
			mCurrBackColor = mBackColor.getColorForState(getDrawableState(), mCurrBackColor);
			mNextBackColor = mBackColor.getColorForState(nextState, mCurrBackColor);
		} else {
			if (mBackDrawable instanceof StateListDrawable && mFadeBack) {
				mBackDrawable.setState(nextState);
				mNextBackDrawable = mBackDrawable.getCurrent().mutate();
			} else {
				mNextBackDrawable = null;
			}
			setDrawableState(mBackDrawable);
			if (mBackDrawable != null) {
				mCurrentBackDrawable = mBackDrawable.getCurrent().mutate();
			}
		}
	}

	@Override
	public boolean onTouchEvent(MotionEvent event) {

		if (!isEnabled() || !isClickable()) {
			return false;
		}

		int action = event.getAction();

		float deltaX = event.getX() - mStartX;
		float deltaY = event.getY() - mStartY;

		// status the view going to change to when finger released
		boolean nextStatus;

		switch (action) {
			case MotionEvent.ACTION_DOWN:
				catchView();
				mStartX = event.getX();
				mStartY = event.getY();
				mLastX = mStartX;
				setPressed(true);
				break;

			case MotionEvent.ACTION_MOVE:
				float x = event.getX();
				setProcess(getProcess() + (x - mLastX) / mSafeRectF.width());
				mLastX = x;
				break;

			case MotionEvent.ACTION_CANCEL:
			case MotionEvent.ACTION_UP:
				setPressed(false);
				nextStatus = getStatusBasedOnPos();
				float time = event.getEventTime() - event.getDownTime();
				if (deltaX < mTouchSlop && deltaY < mTouchSlop && time < mClickTimeout) {
					performClick();
				} else {
					if (nextStatus != isChecked()) {
						playSoundEffect(SoundEffectConstants.CLICK);
						setChecked(nextStatus);
					} else {
						animateToState(nextStatus);
					}
				}
				break;

			default:
				break;
		}
		return true;
	}


	/**
	 * return the status based on position of thumb
	 *
	 * @return
	 */
	private boolean getStatusBasedOnPos() {
		return getProcess() > 0.5f;
	}

	public final float getProcess() {
		return mProcess;
	}

	public final void setProcess(final float process) {
		float tp = process;
		if (tp > 1) {
			tp = 1;
		} else if (tp < 0) {
			tp = 0;
		}
		this.mProcess = tp;
		invalidate();
	}

	@Override
	public boolean performClick() {
		return super.performClick();
	}

	/**
	 * processing animation
	 *
	 * @param checked checked or unChecked
	 */
	protected void animateToState(boolean checked) {
		if (mProcessAnimator == null) {
			return;
		}
		if (mProcessAnimator.isRunning()) {
			mProcessAnimator.cancel();
		}
		mProcessAnimator.setDuration(mAnimationDuration);
		if (checked) {
			mProcessAnimator.setFloatValues(mProcess, 1f);
		} else {
			mProcessAnimator.setFloatValues(mProcess, 0);
		}
		mProcessAnimator.start();
	}

	private void catchView() {
		ViewParent parent = getParent();
		if (parent != null) {
			parent.requestDisallowInterceptTouchEvent(true);
		}
	}

	@Override
	public void setChecked(final boolean checked) {
		// animate before super.setChecked() become user may call setChecked again in OnCheckedChangedListener
		if (isChecked() != checked) {
			animateToState(checked);
		}
		super.setChecked(checked);
	}

	public void setCheckedImmediately(boolean checked) {
		super.setChecked(checked);
		if (mProcessAnimator != null && mProcessAnimator.isRunning()) {
			mProcessAnimator.cancel();
		}
		setProcess(checked ? 1 : 0);
		invalidate();
	}

	public void toggleImmediately() {
		setCheckedImmediately(!isChecked());
	}

	private void setDrawableState(Drawable drawable) {
		if (drawable != null) {
			int[] myDrawableState = getDrawableState();
			drawable.setState(myDrawableState);
			invalidate();
		}
	}

	public boolean isDrawDebugRect() {
		return mDrawDebugRect;
	}

	public void setDrawDebugRect(boolean drawDebugRect) {
		mDrawDebugRect = drawDebugRect;
		invalidate();
	}

	public long getAnimationDuration() {
		return mAnimationDuration;
	}

	public void setAnimationDuration(long animationDuration) {
		mAnimationDuration = animationDuration;
	}

	public Drawable getThumbDrawable() {
		return mThumbDrawable;
	}

	public void setThumbDrawable(Drawable thumbDrawable) {
		mThumbDrawable = thumbDrawable;
		mIsThumbUseDrawable = mThumbDrawable != null;
		setup();
		refreshDrawableState();
		requestLayout();
		invalidate();
	}

	public void setThumbDrawableRes(int thumbDrawableRes) {
		setThumbDrawable(ContextCompat.getDrawable(getContext(), thumbDrawableRes));
	}

	public Drawable getBackDrawable() {
		return mBackDrawable;
	}

	public void setBackDrawable(Drawable backDrawable) {
		mBackDrawable = backDrawable;
		mIsBackUseDrawable = mBackDrawable != null;
		setup();
		refreshDrawableState();
		requestLayout();
		invalidate();
	}

	public void setBackDrawableRes(int backDrawableRes) {
		setBackDrawable(ContextCompat.getDrawable(getContext(), backDrawableRes));
	}

	public ColorStateList getBackColor() {
		return mBackColor;
	}

	public void setBackColor(ColorStateList backColor) {
		mBackColor = backColor;
		if (mBackColor != null) {
			setBackDrawable(null);
		}
		invalidate();
	}

	public void setBackColorRes(int backColorRes) {
		setBackColor(ContextCompat.getColorStateList(getContext(), backColorRes));
	}

	public ColorStateList getThumbColor() {
		return mThumbColor;
	}

	public void setThumbColor(ColorStateList thumbColor) {
		mThumbColor = thumbColor;
		if (mThumbColor != null) {
			setThumbDrawable(null);
		}
	}

	public void setThumbColorRes(int thumbColorRes) {
		setThumbColor(ContextCompat.getColorStateList(getContext(), thumbColorRes));
	}

	public float getBackMeasureRatio() {
		return mBackMeasureRatio;
	}

	public void setBackMeasureRatio(float backMeasureRatio) {
		mBackMeasureRatio = backMeasureRatio;
		requestLayout();
	}

	public RectF getThumbMargin() {
		return mThumbMargin;
	}

	public void setThumbMargin(RectF thumbMargin) {
		if (thumbMargin == null) {
			setThumbMargin(0, 0, 0, 0);
		} else {
			setThumbMargin(thumbMargin.left, thumbMargin.top, thumbMargin.right, thumbMargin.bottom);
		}
	}

	public void setThumbMargin(float left, float top, float right, float bottom) {
		mThumbMargin.set(left, top, right, bottom);
		requestLayout();
	}

	public void setThumbSize(float width, float height) {
		mThumbSizeF.set(width, height);
		setup();
		requestLayout();
	}

	public float getThumbWidth() {
		return mThumbSizeF.x;
	}

	public float getThumbHeight() {
		return mThumbSizeF.y;
	}

	public void setThumbSize(PointF size) {
		if (size == null) {
			float defaultSize = getResources().getDisplayMetrics().density * DEFAULT_THUMB_SIZE_DP;
			setThumbSize(defaultSize, defaultSize);
		} else {
			setThumbSize(size.x, size.y);
		}
	}

	public PointF getThumbSizeF() {
		return mThumbSizeF;
	}

	public float getThumbRadius() {
		return mThumbRadius;
	}

	public void setThumbRadius(float thumbRadius) {
		mThumbRadius = thumbRadius;
		if (!mIsThumbUseDrawable) {
			invalidate();
		}
	}

	public PointF getBackSizeF() {
		return new PointF(mBackRectF.width(), mBackRectF.height());
	}

	public float getBackRadius() {
		return mBackRadius;
	}

	public void setBackRadius(float backRadius) {
		mBackRadius = backRadius;
		if (!mIsBackUseDrawable) {
			invalidate();
		}
	}

	public boolean isFadeBack() {
		return mFadeBack;
	}

	public void setFadeBack(boolean fadeBack) {
		mFadeBack = fadeBack;
	}

	public int getTintColor() {
		return mTintColor;
	}

	public void setTintColor(int tintColor) {
		mTintColor = tintColor;
		mThumbColor = ColorUtils.generateThumbColorWithTintColor(mTintColor);
		mBackColor = ColorUtils.generateBackColorWithTintColor(mTintColor);
		mIsBackUseDrawable = false;
		mIsThumbUseDrawable = false;
		// call this method to refresh color states
		refreshDrawableState();
		invalidate();
	}

	public void setText(CharSequence onText, CharSequence offText) {
		mTextOn = onText;
		mTextOff = offText;

		mOnLayout = null;
		mOffLayout = null;

		requestLayout();
	}


	@Override
	public Parcelable onSaveInstanceState() {
		Parcelable superState = super.onSaveInstanceState();
		SavedState ss = new SavedState(superState);
		ss.onText = mTextOn;
		ss.offText = mTextOff;
		return ss;
	}

	@Override
	public void onRestoreInstanceState(Parcelable state) {
		SavedState ss = (SavedState) state;
		setText(ss.onText, ss.offText);
		super.onRestoreInstanceState(ss.getSuperState());
	}

	static class SavedState extends BaseSavedState {
		CharSequence onText;
		CharSequence offText;

		SavedState(Parcelable superState) {
			super(superState);
		}

		private SavedState(Parcel in) {
			super(in);
			onText = TextUtils.CHAR_SEQUENCE_CREATOR.createFromParcel(in);
			offText = TextUtils.CHAR_SEQUENCE_CREATOR.createFromParcel(in);
		}

		@Override
		public void writeToParcel(Parcel out, int flags) {
			super.writeToParcel(out, flags);
			TextUtils.writeToParcel(onText, out, flags);
			TextUtils.writeToParcel(offText, out, flags);
		}

		public static final Parcelable.Creator<SavedState> CREATOR
				= new Parcelable.Creator<SavedState>() {
			public SavedState createFromParcel(Parcel in) {
				return new SavedState(in);
			}

			public SavedState[] newArray(int size) {
				return new SavedState[size];
			}
		};
	}
}
