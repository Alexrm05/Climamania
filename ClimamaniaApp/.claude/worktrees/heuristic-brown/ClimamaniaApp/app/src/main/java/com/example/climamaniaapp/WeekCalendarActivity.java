package com.example.climamaniaapp;

import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.TableLayout;
import android.widget.TableRow;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

public class WeekCalendarActivity extends AppCompatActivity {

    private TableLayout weekTable;
    private final String[] days = {"Lun", "Mar", "Mié", "Jue", "Vie"};
    private final String[] hours = {"8:00", "9:00", "10:00", "11:00", "12:00",
            "13:00", "14:00", "15:00", "16:00", "17:00", "18:00"};

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_week_calendar);

        weekTable = findViewById(R.id.weekTable);

        // Cabecera de días
        TableRow header = new TableRow(this);
        header.addView(makeCell("")); // celda vacía para esquina
        for (String d : days) {
            header.addView(makeHeaderCell(d));
        }
        weekTable.addView(header);

        // Filas de horas
        for (String h : hours) {
            TableRow row = new TableRow(this);

            // Primera celda con la hora
            row.addView(makeHeaderCell(h));

            // Columnas para los días
            for (int i = 0; i < days.length; i++) {
                row.addView(makeCell(""));
            }

            weekTable.addView(row);
        }

        // EJEMPLO: añadimos un bloque de instalación
        addEvent(1, 1, 2, "Instalación Split"); // Lunes 9:00–11:00
        addEvent(2, 3, 2, "Mantenimiento");     // Martes 11:00–13:00
        addEvent(5, 5, 2, "Instalación Multi"); // Viernes 13:00–15:00
    }

    private TextView makeCell(String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setGravity(Gravity.CENTER);
        tv.setBackgroundColor(Color.parseColor("#EEEEEE"));
        tv.setLayoutParams(new TableRow.LayoutParams(
                200, ViewGroup.LayoutParams.WRAP_CONTENT));
        tv.setPadding(4, 16, 4, 16);
        return tv;
    }

    private TextView makeHeaderCell(String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setGravity(Gravity.CENTER);
        tv.setTextColor(Color.BLACK);
        tv.setTextSize(14f);
        tv.setBackgroundColor(Color.LTGRAY);
        tv.setLayoutParams(new TableRow.LayoutParams(
                200, ViewGroup.LayoutParams.WRAP_CONTENT));
        tv.setPadding(4, 16, 4, 16);
        return tv;
    }

    private void addEvent(int dayCol, int startHourIndex, int duration, String title) {
        // dayCol = 1 (Lunes) … 5 (Viernes)
        // startHourIndex = índice en el array de horas (0=8:00)
        // duration = cuántas filas ocupa (ej: 2 = 2 horas)

        // Creamos un bloque naranja
        TextView eventView = new TextView(this);
        eventView.setText(title);
        eventView.setGravity(Gravity.CENTER);
        eventView.setBackgroundColor(Color.parseColor("#E37D33"));
        eventView.setTextColor(Color.WHITE);

        // Altura dinámica: 60dp por hora aprox
        int heightPerHour = (int) (60 * getResources().getDisplayMetrics().density);
        eventView.setLayoutParams(new TableRow.LayoutParams(
                200, heightPerHour * duration
        ));

        // Insertamos el evento en la tabla
        TableRow row = (TableRow) weekTable.getChildAt(startHourIndex + 1);
        row.removeViewAt(dayCol);
        row.addView(eventView, dayCol);

        // Eliminar celdas de horas siguientes (para que no duplique)
        for (int i = 1; i < duration; i++) {
            TableRow nextRow = (TableRow) weekTable.getChildAt(startHourIndex + 1 + i);
            TextView placeholder = new TextView(this);
            placeholder.setText(""); // vacío
            placeholder.setLayoutParams(new TableRow.LayoutParams(200, 0)); // colapsa
            nextRow.removeViewAt(dayCol);
            nextRow.addView(placeholder, dayCol);
        }
    }

}
