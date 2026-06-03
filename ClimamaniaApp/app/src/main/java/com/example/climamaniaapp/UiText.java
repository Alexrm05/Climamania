package com.example.climamaniaapp;

import android.graphics.Color;
import android.graphics.Typeface;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.StyleSpan;
import android.widget.TextView;

import java.util.Locale;

public final class UiText {

    private static final int PLACEHOLDER_COLOR = Color.parseColor("#8E8E8E");

    private UiText() {
    }

    public static String sanitizeDbValue(String value) {
        if (value == null) return "";
        String clean = value.replace("\u00A0", " ").trim();
        if (clean.isEmpty()) return "";
        String lower = clean.toLowerCase(Locale.ROOT);
        if (lower.equals("-")
                || lower.equals("null")
                || lower.equals("undefined")
                || lower.equals("n/a")
                || lower.equals("na")) {
            return "";
        }
        return clean;
    }

    public static boolean isMissingDbValue(String value) {
        return sanitizeDbValue(value).isEmpty();
    }

    public static String displayValue(String value, String placeholder) {
        String clean = sanitizeDbValue(value);
        return clean.isEmpty() ? safePlaceholder(placeholder) : clean;
    }

    public static CharSequence placeholderSpan(String placeholder) {
        String text = safePlaceholder(placeholder);
        SpannableString span = new SpannableString(text);
        span.setSpan(new ForegroundColorSpan(PLACEHOLDER_COLOR), 0, text.length(),
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        span.setSpan(new StyleSpan(Typeface.ITALIC), 0, text.length(),
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        return span;
    }

    public static void setTextOrPlaceholder(TextView view, String value, String placeholder) {
        if (view == null) return;
        String clean = sanitizeDbValue(value);
        if (clean.isEmpty()) {
            view.setText(placeholderSpan(placeholder));
        } else {
            view.setText(clean);
        }
    }

    public static void setLabelOrPlaceholder(TextView view, String label, String value, String placeholder) {
        if (view == null) return;
        String clean = sanitizeDbValue(value);
        if (clean.isEmpty()) {
            view.setText(placeholderSpan(placeholder));
        } else {
            String safeLabel = sanitizeDbValue(label);
            if (safeLabel.isEmpty()) {
                view.setText(clean);
            } else {
                view.setText(safeLabel + ": " + clean);
            }
        }
    }

    private static String safePlaceholder(String placeholder) {
        String clean = sanitizeDbValue(placeholder);
        return clean.isEmpty() ? "Dato no disponible" : clean;
    }
}
