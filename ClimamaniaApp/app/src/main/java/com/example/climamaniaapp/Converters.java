package com.example.climamaniaapp;

import androidx.room.TypeConverter;

import java.util.Calendar;

public class Converters {

    @TypeConverter
    public static Long fromCalendar(Calendar cal) {
        return (cal == null) ? null : cal.getTimeInMillis();
    }

    @TypeConverter
    public static Calendar toCalendar(Long value) {
        if (value == null) return null;
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(value);
        return c;
    }
}
