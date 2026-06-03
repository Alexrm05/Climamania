package com.example.climamaniaapp;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.util.AttributeSet;
import android.util.Base64;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewParent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;

public class SignaturePadView extends View {

    private final Paint strokePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path signaturePath = new Path();
    private float lastX;
    private float lastY;
    private boolean hasSignature;
    private boolean drawingEnabled = true;

    public SignaturePadView(Context context) {
        super(context);
        init();
    }

    public SignaturePadView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public SignaturePadView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        strokePaint.setStyle(Paint.Style.STROKE);
        strokePaint.setStrokeWidth(dp(2.4f));
        strokePaint.setColor(Color.parseColor("#1F2933"));
        strokePaint.setStrokeCap(Paint.Cap.ROUND);
        strokePaint.setStrokeJoin(Paint.Join.ROUND);
        setBackgroundColor(Color.WHITE);
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        super.onDraw(canvas);
        canvas.drawPath(signaturePath, strokePaint);
    }

    @Override
    public boolean onTouchEvent(@NonNull MotionEvent event) {
        if (!drawingEnabled) {
            requestParentNoIntercept(false);
            return false;
        }
        float x = event.getX();
        float y = event.getY();

        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
                requestParentNoIntercept(true);
                signaturePath.moveTo(x, y);
                lastX = x;
                lastY = y;
                hasSignature = true;
                invalidate();
                return true;
            case MotionEvent.ACTION_MOVE:
                requestParentNoIntercept(true);
                signaturePath.quadTo(lastX, lastY, (x + lastX) / 2f, (y + lastY) / 2f);
                lastX = x;
                lastY = y;
                invalidate();
                return true;
            case MotionEvent.ACTION_UP:
                requestParentNoIntercept(false);
                signaturePath.lineTo(x, y);
                invalidate();
                return true;
            case MotionEvent.ACTION_CANCEL:
                requestParentNoIntercept(false);
                return true;
            default:
                return false;
        }
    }

    public void clear() {
        signaturePath.reset();
        hasSignature = false;
        invalidate();
    }

    public boolean hasSignature() {
        return hasSignature;
    }

    public void setDrawingEnabled(boolean enabled) {
        drawingEnabled = enabled;
    }

    public boolean isDrawingEnabled() {
        return drawingEnabled;
    }

    public Bitmap exportToBitmap() {
        int width = Math.max(getWidth(), 1);
        int height = Math.max(getHeight(), 1);
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        canvas.drawColor(Color.WHITE);
        canvas.drawPath(signaturePath, strokePaint);
        return bitmap;
    }

    public String exportToBase64Png() {
        Bitmap bitmap = exportToBitmap();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
        byte[] bytes = out.toByteArray();
        return Base64.encodeToString(bytes, Base64.NO_WRAP);
    }

    private float dp(float value) {
        return value * getResources().getDisplayMetrics().density;
    }

    private void requestParentNoIntercept(boolean disallow) {
        ViewParent parent = getParent();
        while (parent != null) {
            parent.requestDisallowInterceptTouchEvent(disallow);
            parent = parent.getParent();
        }
    }
}
