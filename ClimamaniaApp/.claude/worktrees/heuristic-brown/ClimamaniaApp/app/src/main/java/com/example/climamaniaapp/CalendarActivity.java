package com.example.climamaniaapp;

import android.annotation.SuppressLint;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.util.Log;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TableLayout;
import android.widget.TableRow;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import android.text.TextUtils;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

public class CalendarActivity extends BaseActivity {

    private static final String EVENTS_URL = "https://app.clminstal.es/api/get_events.php";
    private static final String API_KEY = "TEST123";
    // Color base por defecto (cuando no hay equipo)
    private static final int CARD_BACKGROUND_DEFAULT = Color.parseColor("#F2FFFFFF"); // blanco 95%

    private TableLayout weekTable;
    private FrameLayout calendarFrame;
    private FrameLayout calendarOverlay;
    private TextView txtWeekRange;
    private TextView txtEquipoFilter;

    private final String[] days = { "Lun", "Mar", "Mié", "Jue", "Vie" };
    private final String[] hours = {
            "8:00", "9:00", "10:00", "11:00", "12:00",
            "13:00", "14:00", "15:00", "16:00", "17:00",
            "18:00", "19:00", "20:00"
    };

    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());

    private Calendar currentWeekStart;
    private final List<Evento> eventos = new ArrayList<>();

    // Caché en memoria para no tener que recargar los eventos en cada apertura
    private static List<Evento> cachedEventos;
    private static long cachedAtMillis;
    private static String cachedRol;
    private static String cachedEquipo;
    private static final long CACHE_TTL_MS = 2 * 60 * 1000; // 2 minutos

    // Filtros activos
    private final java.util.Set<String> filtrosEquipos = new java.util.HashSet<>();
    private String filtroEstado = "Todos los estados";
    private String equipoCodigo;

    private int lastCalendarWidth = -1;
    private int lastCalendarHeight = -1;
    private int renderVersion = 0;
    private GestureDetector weekSwipeDetector;
    private long lastWeekSwipeAtMs = 0L;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View calendarContent = getLayoutInflater().inflate(R.layout.content_calendar, contentFrame, true);

        setupBottomBar();

        txtWeekRange = calendarContent.findViewById(R.id.txtWeekRange);
        weekTable = calendarContent.findViewById(R.id.weekTable);
        calendarFrame = calendarContent.findViewById(R.id.calendarFrame);
        calendarOverlay = calendarContent.findViewById(R.id.calendarOverlay);
        txtEquipoFilter = calendarContent.findViewById(R.id.txtEquipoFilter);
        Spinner spinnerEstadoFilter = calendarContent.findViewById(R.id.spinnerEstadoFilter);

        currentWeekStart = Calendar.getInstance(Locale.forLanguageTag("es-ES"));
        currentWeekStart.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY);

        calendarContent.findViewById(R.id.btnPrevWeek).setOnClickListener(v -> {
            currentWeekStart.add(Calendar.DAY_OF_MONTH, -7);
            updateWeekLabel();
            calendarFrame.post(this::refreshCalendar);
        });

        calendarContent.findViewById(R.id.btnNextWeek).setOnClickListener(v -> {
            currentWeekStart.add(Calendar.DAY_OF_MONTH, 7);
            updateWeekLabel();
            calendarFrame.post(this::refreshCalendar);
        });

        // Configuración de filtros (equipo y estado)
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = prefs.getString("rol", "");
        boolean isAdmin = "adminclm".equalsIgnoreCase(rol);

        if (txtEquipoFilter != null) {
            if (isAdmin) {
                txtEquipoFilter.setOnClickListener(v -> mostrarDialogoFiltrosEquipo());
                actualizarEtiquetaFiltroEquipos();
            } else {
                String equipoStr = readEquipoFromPrefs(prefs);
                String equipoLabel = (equipoStr != null && !equipoStr.trim().isEmpty()
                        && !"0".equals(equipoStr.trim()))
                                ? "Equipo " + equipoStr.trim()
                                : "Equipo no asignado";
                txtEquipoFilter.setText(equipoLabel);
                txtEquipoFilter.setClickable(false);
                txtEquipoFilter.setEnabled(false);
                txtEquipoFilter.setAlpha(0.7f);
            }
        }

        if (spinnerEstadoFilter != null) {
            android.widget.ArrayAdapter<CharSequence> adapterEstados = android.widget.ArrayAdapter.createFromResource(
                    this,
                    R.array.filter_estados,
                    android.R.layout.simple_spinner_item);
            adapterEstados.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
            spinnerEstadoFilter.setAdapter(adapterEstados);
            spinnerEstadoFilter.setSelection(0);
            spinnerEstadoFilter.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
                @Override
                public void onItemSelected(android.widget.AdapterView<?> parent, View view, int position, long id) {
                    Object item = parent.getItemAtPosition(position);
                    filtroEstado = item != null ? item.toString() : "Todos los estados";
                    refreshCalendar();
                }

                @Override
                public void onNothingSelected(android.widget.AdapterView<?> parent) {
                    filtroEstado = "Todos los estados";
                    refreshCalendar();
                }
            });
        }

        // Botón "Hoy" para volver rápidamente a la semana actual
        TextView btnToday = calendarContent.findViewById(R.id.btnToday);
        if (btnToday != null) {
            btnToday.setOnClickListener(v -> {
                Calendar today = Calendar.getInstance(Locale.forLanguageTag("es-ES"));
                today.setFirstDayOfWeek(Calendar.MONDAY);
                today.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY);
                currentWeekStart = today;
                updateWeekLabel();
                calendarFrame.post(this::refreshCalendar);
            });
        }

        // Cargar eventos desde el servidor
        cargarEventos();
        updateWeekLabel();
        calendarFrame.post(this::refreshCalendar);

        if (calendarFrame != null) {
            calendarFrame.addOnLayoutChangeListener((v, left, top, right, bottom,
                    oldLeft, oldTop, oldRight, oldBottom) -> {
                int width = right - left;
                int height = bottom - top;
                if (width != lastCalendarWidth || height != lastCalendarHeight) {
                    lastCalendarWidth = width;
                    lastCalendarHeight = height;
                    calendarFrame.post(this::refreshCalendar);
                }
            });
        }

        initWeekSwipeNavigation();
    }

    private void initWeekSwipeNavigation() {
        weekSwipeDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onDown(MotionEvent e) {
                // Necesario para que onFling se dispare de forma consistente.
                return true;
            }

            @Override
            public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
                if (e1 == null || e2 == null || calendarFrame == null) {
                    return false;
                }
                if (!isInsideView(e1, calendarFrame) || !isInsideView(e2, calendarFrame)) {
                    return false;
                }

                float dx = e2.getRawX() - e1.getRawX();
                float dy = e2.getRawY() - e1.getRawY();

                int minDistancePx = dp(56);
                int minVelocityPx = dp(120);

                if (Math.abs(dx) < minDistancePx) {
                    return false;
                }
                if (Math.abs(dx) <= Math.abs(dy)) {
                    return false;
                }
                if (Math.abs(velocityX) < minVelocityPx) {
                    return false;
                }

                long now = System.currentTimeMillis();
                if (now - lastWeekSwipeAtMs < 280L) {
                    return true;
                }
                lastWeekSwipeAtMs = now;

                if (dx < 0f) {
                    goToNextWeek();
                } else {
                    goToPreviousWeek();
                }
                return true;
            }
        });
    }

    private void goToPreviousWeek() {
        currentWeekStart.add(Calendar.DAY_OF_MONTH, -7);
        updateWeekLabel();
        calendarFrame.post(this::refreshCalendar);
    }

    private void goToNextWeek() {
        currentWeekStart.add(Calendar.DAY_OF_MONTH, 7);
        updateWeekLabel();
        calendarFrame.post(this::refreshCalendar);
    }

    private boolean isInsideView(MotionEvent event, View target) {
        if (event == null || target == null || target.getWidth() <= 0 || target.getHeight() <= 0) {
            return false;
        }
        int[] location = new int[2];
        target.getLocationOnScreen(location);
        float x = event.getRawX();
        float y = event.getRawY();
        return x >= location[0]
                && x <= (location[0] + target.getWidth())
                && y >= location[1]
                && y <= (location[1] + target.getHeight());
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent ev) {
        if (weekSwipeDetector != null && ev != null) {
            weekSwipeDetector.onTouchEvent(ev);
        }
        return super.dispatchTouchEvent(ev);
    }

    private void cargarEventos() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = prefs.getString("rol", "");
        String usuario = prefs.getString("usuario", "");
        String equipoStr = readEquipoFromPrefs(prefs);
        final String equipoStrFinal = equipoStr;

        // Si tenemos datos recientes en caché para este rol/equipo, los usamos
        // inmediatamente
        long now = System.currentTimeMillis();
        if (cachedEventos != null
                && rol.equals(cachedRol)
                && equipoStr.equals(cachedEquipo)
                && (now - cachedAtMillis) < CACHE_TTL_MS) {
            eventos.clear();
            eventos.addAll(cachedEventos);
            refreshCalendar();
            // Aun así lanzamos una recarga en segundo plano para mantener los datos frescos
        }

        try {
            String url = EVENTS_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, StandardCharsets.UTF_8)
                    + "&rol=" + URLEncoder.encode(rol, StandardCharsets.UTF_8)
                    + "&equipo=" + URLEncoder.encode(equipoStrFinal, StandardCharsets.UTF_8)
                    + "&usuario=" + URLEncoder.encode(usuario, StandardCharsets.UTF_8);

            RequestQueue queue = Volley.newRequestQueue(this);

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> {
                        try {
                            JSONObject json = new JSONObject(response);
                            boolean success = json.optBoolean("success", false);
                            if (!success) {
                                String message = json.optString("message", "Error al cargar eventos");
                                Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
                                return;
                            }

                            JSONArray arr = json.optJSONArray("eventos");
                            eventos.clear();

                            if (arr != null) {
                                for (int i = 0; i < arr.length(); i++) {
                                    JSONObject evJson = arr.getJSONObject(i);
                                    String startStr = UiText.sanitizeDbValue(evJson.optString("start", ""));
                                    String endStr = UiText.sanitizeDbValue(evJson.optString("end", ""));
                                    String referencia = UiText.sanitizeDbValue(evJson.optString("referencia", ""));
                                    String titulo = UiText.sanitizeDbValue(evJson.optString("title", ""));
                                    String direccion = UiText.sanitizeDbValue(evJson.optString("direccion", ""));
                                    String nombreCliente = UiText.sanitizeDbValue(evJson.optString("nombrecliente", ""));
                                    String telefono = UiText.sanitizeDbValue(evJson.optString("telefono", ""));
                                    String whatsapp = UiText.sanitizeDbValue(evJson.optString("whatsapp", ""));
                                    String estado = UiText.sanitizeDbValue(evJson.optString("estado", ""));
                                    String detalles = UiText.sanitizeDbValue(evJson.optString("detalles", ""));
                                    String comentarios = UiText.sanitizeDbValue(evJson.optString("comentarios", ""));
                                    String concertada = UiText.sanitizeDbValue(evJson.optString("concertada", ""));
                                    String emailEquipo = UiText.sanitizeDbValue(evJson.optString("EmailEquipo", ""));
                                    String colorHex = UiText.sanitizeDbValue(evJson.optString("color", ""));
                                    String equipoEvento = UiText.sanitizeDbValue(evJson.optString("equipo_instaladores", ""));

                                    Evento ev = convertirEvento(startStr, endStr,
                                            referencia, direccion, nombreCliente);
                                    if (ev != null) {
                                        ev.equipoCodigo = equipoEvento;
                                        ev.colorHex = colorHex;
                                        ev.telefono = telefono;
                                        ev.whatsapp = whatsapp;
                                        ev.estado = estado;
                                        ev.titulo = titulo;
                                        ev.detalles = detalles;
                                        ev.comentarios = comentarios;
                                        ev.concertada = concertada;
                                        ev.emailEquipo = emailEquipo;
                                        eventos.add(ev);
                                    }
                                }
                            }

                            // Actualizar caché en memoria
                            cachedEventos = new ArrayList<>(eventos);
                            cachedRol = rol;
                            cachedEquipo = equipoStrFinal;
                            cachedAtMillis = System.currentTimeMillis();

                            refreshCalendar();
                        } catch (JSONException e) {
                            Log.e("CalendarActivity", "Error parseando eventos: " + response, e);
                            Toast.makeText(this, "Error al leer eventos", Toast.LENGTH_SHORT).show();
                        }
                    },
                    error -> {
                        String msg;
                        if (error.networkResponse != null) {
                            int statusCode = error.networkResponse.statusCode;
                            msg = "Error al cargar eventos (HTTP " + statusCode + ")";
                        } else {
                            msg = "Error de conexión al cargar eventos";
                        }
                        Log.e("CalendarActivity", "Volley error al cargar eventos", error);
                        Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                    });

            queue.add(request);
        } catch (Exception e) {
            Log.e("CalendarActivity", "Error construyendo URL de eventos", e);
            Toast.makeText(this, "Error interno al preparar la petición", Toast.LENGTH_SHORT).show();
        }
    }

    private Evento convertirEvento(String startStr,
            String endStr,
            String referencia,
            String direccion,
            String nombreCliente) {
        if (startStr == null || startStr.isEmpty())
            return null;
        try {
            java.util.Date startDate = serverDateFormat.parse(startStr);
            java.util.Date endDate;

            if (endStr != null && !endStr.isEmpty()) {
                endDate = serverDateFormat.parse(endStr);
            } else {
                Calendar tmp = Calendar.getInstance();
                assert startDate != null;
                tmp.setTime(startDate);
                tmp.add(Calendar.HOUR_OF_DAY, 1);
                endDate = tmp.getTime();
            }

            Calendar calStart = Calendar.getInstance();
            assert startDate != null;
            calStart.setTime(startDate);

            Calendar calEnd = Calendar.getInstance();
            assert endDate != null;
            calEnd.setTime(endDate);

            int startHour = calStart.get(Calendar.HOUR_OF_DAY);
            int endHour = calEnd.get(Calendar.HOUR_OF_DAY);

            int startIndex = startHour - 8; // 0 => 08:00
            if (startIndex < 0 || startIndex >= hours.length) {
                // Fuera del rango visible del calendario
                return null;
            }

            int duration = Math.max(1, endHour - startHour);
            if (startIndex + duration > hours.length) {
                duration = hours.length - startIndex;
            }

            return new Evento(calStart, startIndex, duration,
                    referencia, direccion, nombreCliente);
        } catch (ParseException e) {
            Log.e("CalendarActivity", "Fecha de evento inválida: " + startStr + " / " + endStr, e);
            return null;
        }
    }

    private void updateWeekLabel() {
        SimpleDateFormat sdf = new SimpleDateFormat("dd MMM yyyy", Locale.forLanguageTag("es-ES"));
        Calendar weekEnd = (Calendar) currentWeekStart.clone();
        weekEnd.add(Calendar.DAY_OF_MONTH, 6);

        String rango = sdf.format(currentWeekStart.getTime()) + " - " + sdf.format(weekEnd.getTime());
        // Verificación para evitar NullPointerException si la vista aún no está lista
        if (txtWeekRange != null) {
            txtWeekRange.setText(rango);
        }
    }

    private void refreshCalendar() {
        // Verificación para evitar NullPointerException
        if (calendarFrame == null || calendarOverlay == null || weekTable == null) {
            Log.e("CalendarActivity", "refreshCalendar llamado antes de que las vistas estén inicializadas.");
            return;
        }

        renderVersion++;
        final int currentRender = renderVersion;

        // Limpiar solo las capas de eventos, dejando la tabla intacta
        for (int i = calendarOverlay.getChildCount() - 1; i >= 0; i--) {
            View child = calendarOverlay.getChildAt(i);
            if (child != weekTable) {
                calendarOverlay.removeViewAt(i);
            }
        }

        weekTable.removeAllViews();

        TableRow header = new TableRow(this);
        header.addView(makeHeaderCell("", false, true));

        Calendar dayPointer = (Calendar) currentWeekStart.clone();
        // Formato tipo "8 dic" para tener cabeceras más bajas en una sola línea
        SimpleDateFormat sdfDay = new SimpleDateFormat("d MMM", Locale.forLanguageTag("es-ES"));

        for (String day : days) {
            boolean isToday = dayPointer.get(Calendar.DAY_OF_YEAR) == Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
                    && dayPointer.get(Calendar.YEAR) == Calendar.getInstance().get(Calendar.YEAR);

            // Ejemplo: "Lun - 8 dic"
            String label = day + " - " + sdfDay.format(dayPointer.getTime());
            header.addView(makeHeaderCell(label, isToday, false));
            dayPointer.add(Calendar.DAY_OF_MONTH, 1);
        }
        weekTable.addView(header);

        for (String h : hours) {
            TableRow row = new TableRow(this);
            row.addView(makeCell(h, true));
            for (int i = 0; i < days.length; i++) {
                row.addView(makeCell("", false));
            }
            weekTable.addView(row);
        }

        Calendar weekEnd = (Calendar) currentWeekStart.clone();
        weekEnd.add(Calendar.DAY_OF_MONTH, 6);

        // 1) Agrupar eventos de la semana actual por día y franja horaria,
        // aplicando filtros de equipo/estado
        java.util.Map<String, java.util.List<Evento>> slotEvents = new java.util.HashMap<>();
        java.util.Map<String, Integer> slotDayCols = new java.util.HashMap<>();

        for (Evento ev : eventos) {
            if (!pasaFiltros(ev)) {
                continue;
            }
            Calendar eventDate = (Calendar) ev.fecha.clone();
            eventDate.set(Calendar.HOUR_OF_DAY, 0);
            eventDate.set(Calendar.MINUTE, 0);
            eventDate.set(Calendar.SECOND, 0);
            eventDate.set(Calendar.MILLISECOND, 0);

            Calendar weekStartNormalized = (Calendar) currentWeekStart.clone();
            weekStartNormalized.set(Calendar.HOUR_OF_DAY, 0);
            weekStartNormalized.set(Calendar.MINUTE, 0);
            weekStartNormalized.set(Calendar.SECOND, 0);
            weekStartNormalized.set(Calendar.MILLISECOND, 0);

            Calendar weekEndNormalized = (Calendar) weekEnd.clone();
            weekEndNormalized.set(Calendar.HOUR_OF_DAY, 0);
            weekEndNormalized.set(Calendar.MINUTE, 0);
            weekEndNormalized.set(Calendar.SECOND, 0);
            weekEndNormalized.set(Calendar.MILLISECOND, 0);

            if (!eventDate.before(weekStartNormalized) && !eventDate.after(weekEndNormalized)) {
                int dayOfWeek = ev.fecha.get(Calendar.DAY_OF_WEEK);

                int dayCol = -1;
                switch (dayOfWeek) {
                    case Calendar.MONDAY:
                        dayCol = 1;
                        break;
                    case Calendar.TUESDAY:
                        dayCol = 2;
                        break;
                    case Calendar.WEDNESDAY:
                        dayCol = 3;
                        break;
                    case Calendar.THURSDAY:
                        dayCol = 4;
                        break;
                    case Calendar.FRIDAY:
                        dayCol = 5;
                        break;
                }

                if (dayCol != -1) {
                    String key = dayCol + "_" + ev.startHourIndex;
                    slotDayCols.put(key, dayCol);
                    java.util.List<Evento> list = slotEvents.computeIfAbsent(key, k -> new ArrayList<>());
                    list.add(ev);
                }
            }
        }

        // 2) Dibujar cada franja: un evento normal o un bloque agrupado si hay varios
        for (java.util.Map.Entry<String, java.util.List<Evento>> entry : slotEvents.entrySet()) {
            String key = entry.getKey();
            java.util.List<Evento> list = entry.getValue();
            if (list.isEmpty())
                continue;

            int underscore = key.indexOf('_');
            int startIndex = Integer.parseInt(key.substring(underscore + 1));
            int dayCol = slotDayCols.get(key);

            // Duración: la máxima de los eventos de esa franja
            int duration = 1;
            for (Evento ev : list) {
                if (ev.duration > duration)
                    duration = ev.duration;
            }

            if (list.size() == 1) {
                drawEventSingle(dayCol, startIndex, duration, list.get(0), currentRender);
            } else {
                drawEventGroup(dayCol, startIndex, duration, list, currentRender);
            }
        }
    }

    private TextView makeCell(String text, boolean isHourColumn) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setGravity(Gravity.CENTER);
        tv.setBackgroundResource(isHourColumn
                ? R.drawable.bg_cell_hour
                : R.drawable.bg_cell);

        // Columna de horas más estrecha, días más anchos.
        // Altura moderada para que el calendario sea más compacto.
        int height = dp(70);

        int width = isHourColumn ? dp(32) : dp(120);
        tv.setLayoutParams(new TableRow.LayoutParams(width, height));
        tv.setPadding(4, 24, 4, 24);
        tv.setTextSize(isHourColumn ? 12f : 11f);
        tv.setTextColor(isHourColumn
                ? Color.parseColor("#757575")
                : Color.parseColor("#424242"));
        return tv;
    }

    private TextView makeHeaderCell(String text, boolean isToday, boolean isHourColumn) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setGravity(Gravity.CENTER);
        tv.setTextColor(ContextCompat.getColor(this, R.color.calendarHeaderText));
        tv.setTextSize(13f);
        tv.setTypeface(null, android.graphics.Typeface.BOLD);
        if (isHourColumn) {
            tv.setBackgroundResource(R.drawable.bg_cell_hour);
        } else {
            tv.setBackgroundResource(R.drawable.bg_header);
        }

        // Columna de horas más estrecha, días más anchos
        int width = isHourColumn ? dp(32) : dp(120);
        tv.setLayoutParams(new TableRow.LayoutParams(width, ViewGroup.LayoutParams.WRAP_CONTENT));
        // Menos padding vertical para que la fila de días sea más baja
        tv.setPadding(4, 14, 4, 14);

        if (isToday && !isHourColumn) {
            // Resalte suave de la columna de "hoy"
            tv.setBackgroundColor(Color.parseColor("#FFF3E0")); // naranja muy claro
            tv.setTextColor(Color.parseColor("#BF360C"));
        }
        return tv;
    }

    private String formatDireccion(Evento ev) {
        return formatDireccion(ev != null ? ev.direccion : null);
    }

    private String formatDireccion(String rawDireccion) {
        String raw = UiText.sanitizeDbValue(rawDireccion);

        // Normalizar saltos de línea HTML a saltos de línea reales
        raw = raw.replace("<br/>", "\n")
                .replace("<br />", "\n")
                .replace("<br>", "\n")
                .replace("<BR/>", "\n")
                .replace("<BR />", "\n")
                .replace("<BR>", "\n");

        // Eliminar cualquier etiqueta HTML residual
        raw = raw.replaceAll("<[^>]+>", "");

        return raw.trim();
    }

    private int colorForEquipo(String equipoCodigo) {
        if (equipoCodigo == null) {
            return Color.parseColor("#FFB0BEC5"); // gris claro
        }
        String code = equipoCodigo.trim().toUpperCase(java.util.Locale.ROOT);

        switch (code) {
            case "FCB":
                return Color.parseColor("#FF1976D2"); // azul
            case "FCB2":
                return Color.parseColor("#FFE37D33"); // naranja
            case "JZ":
                return Color.parseColor("#FF388E3C"); // verde
            case "JS":
                return Color.parseColor("#FF7B1FA2"); // morado
            case "MA":
                return Color.parseColor("#FF0097A7"); // turquesa
            case "CLM1":
                return Color.parseColor("#FFFBC02D"); // amarillo
            // Añade aquí más códigos de equipo si los tienes
            default:
                return Color.parseColor("#FFB0BEC5"); // gris claro (sin equipo / otros)
        }
    }

    // Color principal del evento: primero el de la columna "color" (si existe), si
    // no el del equipo.
    private int colorForEvento(Evento ev) {
        if (ev != null && ev.colorHex != null) {
            String hex = ev.colorHex.trim();
            if (!hex.isEmpty()) {
                try {
                    // Permitir valores sin '#'
                    if (!hex.startsWith("#")) {
                        hex = "#" + hex;
                    }
                    return Color.parseColor(hex);
                } catch (IllegalArgumentException ignore) {
                    // Si el formato no es válido, caemos al color por equipo
                }
            }
        }
        return colorForEquipo(ev != null ? ev.equipoCodigo : null);
    }

    private int backgroundColorForEvento(Evento ev) {
        // Menos transparencia → tarjetas más sólidas
        return backgroundColorForEventoInternal(ev, 80); // ~31% opacidad
    }

    private int backgroundColorForEventoStrong(Evento ev) {
        // Versión más intensa para bloques agrupados
        return backgroundColorForEventoInternal(ev, 140); // ~55% opacidad
    }

    private int backgroundColorForEventoInternal(Evento ev, int alpha) {
        int base = colorForEvento(ev);
        int r = Color.red(base);
        int g = Color.green(base);
        int b = Color.blue(base);
        return Color.argb(alpha, r, g, b);
    }

    private TextView createEstadoChip(String estadoRaw) {
        // Regla del cliente: si el texto contiene "finalizado" => FINALIZADO; en otro
        // caso => SIN FINALIZAR
        String safe = UiText.sanitizeDbValue(estadoRaw);
        String lower = safe.toLowerCase(java.util.Locale.ROOT);
        boolean esFinalizado = lower.contains("finalizado");

        int color = esFinalizado
                ? Color.parseColor("#388E3C") // verde para finalizado
                : Color.parseColor("#FB8C00"); // naranja para sin finalizar

        String label = esFinalizado ? "FINALIZADO" : "SIN FINALIZAR";

        TextView chip = new TextView(this);
        chip.setText(label);
        chip.setTextSize(10f);
        chip.setTextColor(Color.WHITE);
        chip.setTypeface(null, Typeface.BOLD);
        chip.setPadding(dp(8), dp(2), dp(8), dp(2));

        android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
        bg.setCornerRadius(dp(10));
        bg.setColor(color);
        chip.setBackground(bg);

        return chip;
    }

    @SuppressLint("SetTextI18n")
    private void drawEventSingle(int dayCol, int startHourIndex, int duration, Evento ev, int renderToken) {
        calendarOverlay.post(() -> {
            if (renderToken != renderVersion)
                return;
            if (weekTable.getChildCount() <= 1)
                return;

            TableRow firstRow = (TableRow) weekTable.getChildAt(1);
            if (firstRow == null || firstRow.getChildCount() <= dayCol)
                return;

            View baseCell = firstRow.getChildAt(dayCol);
            if (baseCell == null)
                return;

            if (baseCell.getWidth() == 0 || firstRow.getHeight() == 0) {
                calendarOverlay.post(() -> drawEventSingle(dayCol, startHourIndex, duration, ev, renderToken));
                return;
            }

            int cellWidth = baseCell.getWidth();
            int cellHeight = firstRow.getHeight();

            // Contenedor horizontal: banda de color + contenido
            LinearLayout eventLayout = new LinearLayout(this);
            eventLayout.setOrientation(LinearLayout.HORIZONTAL);

            // Fondo semitransparente según el color del evento (columna "color" o, si
            // falta, color por equipo)
            android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
            bg.setCornerRadius(dp(8));
            bg.setColor(backgroundColorForEvento(ev));
            // Resalte especial si el evento es hoy
            if (isToday(ev.fecha)) {
                bg.setStroke(dp(2), Color.parseColor("#1976D2"));
            }
            eventLayout.setBackground(bg);

            // Banda lateral con color del evento
            View colorStrip = new View(this);
            LinearLayout.LayoutParams stripParams = new LinearLayout.LayoutParams(dp(5),
                    LinearLayout.LayoutParams.MATCH_PARENT);
            colorStrip.setLayoutParams(stripParams);
            colorStrip.setBackgroundColor(colorForEvento(ev));

            // Contenido textual
            LinearLayout contentLayout = new LinearLayout(this);
            contentLayout.setOrientation(LinearLayout.VERTICAL);
            contentLayout.setPadding(dp(6), dp(6), dp(6), dp(6));
            LinearLayout.LayoutParams contentParams = new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.MATCH_PARENT, 1f);
            contentLayout.setLayoutParams(contentParams);

            TextView txtHora = new TextView(this);
            txtHora.setText(ev.getHoraPrevista(hours));
            txtHora.setTextSize(13f);
            txtHora.setTypeface(null, Typeface.BOLD);
            txtHora.setTextColor(Color.BLACK);

            TextView txtPedido = new TextView(this);
            String pedido = ev.pedido == null ? "" : ev.pedido.trim();
            txtPedido.setText(pedido);
            txtPedido.setTextSize(15f);
            txtPedido.setTypeface(null, Typeface.BOLD);
            txtPedido.setTextColor(Color.BLACK);
            txtPedido.setMaxLines(1);
            txtPedido.setEllipsize(TextUtils.TruncateAt.END);

            TextView txtCliente = new TextView(this);
            String cliente = ev.cliente == null ? "" : ev.cliente.trim();
            txtCliente.setText(cliente);
            txtCliente.setTextSize(13f);
            txtCliente.setTextColor(Color.BLACK);
            txtCliente.setMaxLines(1);
            txtCliente.setEllipsize(TextUtils.TruncateAt.END);

            TextView txtEquipo = new TextView(this);
            txtEquipo.setText(!TextUtils.isEmpty(ev.equipoCodigo)
                    ? "Equipo " + ev.equipoCodigo
                    : "Equipo n/d");
            txtEquipo.setTextSize(12f);
            txtEquipo.setTypeface(null, Typeface.BOLD);
            txtEquipo.setTextColor(colorForEquipo(ev.equipoCodigo));

            TextView txtDireccion = new TextView(this);
            txtDireccion.setText(formatDireccion(ev));
            txtDireccion.setTextSize(12f);
            txtDireccion.setTextColor(Color.parseColor("#263238"));
            txtDireccion.setMaxLines(2);
            txtDireccion.setEllipsize(TextUtils.TruncateAt.END);

            TextView txtTelefono = new TextView(this);
            if (ev.telefono != null && !ev.telefono.trim().isEmpty()) {
                txtTelefono.setText("Tel. " + ev.telefono.trim());
            } else {
                txtTelefono.setVisibility(View.GONE);
            }
            txtTelefono.setTextSize(12f);
            txtTelefono.setTextColor(Color.parseColor("#263238"));
            txtTelefono.setMaxLines(1);
            txtTelefono.setEllipsize(TextUtils.TruncateAt.END);

            TextView txtWhatsapp = new TextView(this);
            if (ev.whatsapp != null && !ev.whatsapp.trim().isEmpty()) {
                txtWhatsapp.setText("WhatsApp: " + ev.whatsapp.trim());
            } else {
                txtWhatsapp.setVisibility(View.GONE);
            }
            txtWhatsapp.setTextSize(12f);
            txtWhatsapp.setTextColor(Color.parseColor("#263238"));
            txtWhatsapp.setMaxLines(1);
            txtWhatsapp.setEllipsize(TextUtils.TruncateAt.END);

            // Cabecera: chip de estado encima de la hora
            LinearLayout headerRow = new LinearLayout(this);
            headerRow.setOrientation(LinearLayout.VERTICAL);
            headerRow.setGravity(Gravity.CENTER_VERTICAL);

            if (isPedidoValido(ev.pedido)) {
                TextView estadoChip = createEstadoChip(ev.estado);
                LinearLayout.LayoutParams chipParams = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT);
                chipParams.bottomMargin = dp(2);
                estadoChip.setLayoutParams(chipParams);
                headerRow.addView(estadoChip);
            }
            headerRow.addView(txtHora);

            contentLayout.addView(headerRow);
            contentLayout.addView(txtPedido);
            contentLayout.addView(txtCliente);
            contentLayout.addView(txtEquipo);
            contentLayout.addView(txtDireccion);
            contentLayout.addView(txtTelefono);
            contentLayout.addView(txtWhatsapp);

            eventLayout.addView(colorStrip);
            eventLayout.addView(contentLayout);

            styleEventCard(eventLayout, ev.equipoCodigo);

            int availableWidth = cellWidth - dp(12);
            int left = baseCell.getLeft() + dp(6);

            int eventHeight = cellHeight * duration - dp(8);
            int top = (firstRow.getTop() + cellHeight * startHourIndex) + dp(4);

            FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                    availableWidth,
                    eventHeight);

            params.leftMargin = left;
            params.topMargin = top;

            // Al tocar la tarjeta, abrimos detalle solo si es un pedido válido
            eventLayout.setOnClickListener(v -> {
                if (!isPedidoValido(ev.pedido)) {
                    Toast.makeText(this,
                            "Este evento no tiene pedido asociado",
                            Toast.LENGTH_SHORT).show();
                    return;
                }
                openEventDetail(ev);
            });

            eventLayout.setAlpha(0f);
            calendarOverlay.addView(eventLayout, params);
            eventLayout.animate().alpha(1f).setDuration(200).start();
        });
    }

    private void openEventDetail(Evento ev) {
        if (ev == null || !isPedidoValido(ev.pedido)) {
            Toast.makeText(this,
                    "Este evento no tiene pedido asociado",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        android.content.Intent intent = new android.content.Intent(CalendarActivity.this, PedidoDetailActivity.class);

        intent.putExtra("referencia", ev.pedido);
        if (ev.cliente != null) {
            intent.putExtra("cliente", ev.cliente);
        }
        startActivity(intent);
    }

    /**
     * Dibuja un bloque que agrupa varios eventos que empiezan a la misma hora.
     * El contenido lista cada pedido con su equipo y cliente.
     */
    @SuppressLint("SetTextI18n")
    private void drawEventGroup(int dayCol, int startHourIndex, int duration, java.util.List<Evento> group,
            int renderToken) {
        calendarOverlay.post(() -> {
            if (renderToken != renderVersion)
                return;
            if (weekTable.getChildCount() <= 1)
                return;

            TableRow firstRow = (TableRow) weekTable.getChildAt(1);
            if (firstRow == null || firstRow.getChildCount() <= dayCol)
                return;

            View baseCell = firstRow.getChildAt(dayCol);
            if (baseCell == null)
                return;

            if (baseCell.getWidth() == 0 || firstRow.getHeight() == 0) {
                calendarOverlay.post(() -> drawEventGroup(dayCol, startHourIndex, duration, group, renderToken));
                return;
            }

            int cellWidth = baseCell.getWidth();
            int cellHeight = firstRow.getHeight();

            LinearLayout container = new LinearLayout(this);
            container.setOrientation(LinearLayout.HORIZONTAL);

            // Fondo semitransparente según el color del primer evento del grupo
            android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
            bg.setCornerRadius(dp(8));
            int groupColor = group.isEmpty()
                    ? CARD_BACKGROUND_DEFAULT
                    : backgroundColorForEventoStrong(group.get(0));
            bg.setColor(groupColor);
            if (!group.isEmpty() && isToday(group.get(0).fecha)) {
                bg.setStroke(dp(2), Color.parseColor("#1976D2"));
            }
            container.setBackground(bg);

            // Banda lateral con el color del primer evento
            View colorStrip = new View(this);
            LinearLayout.LayoutParams stripParams = new LinearLayout.LayoutParams(dp(5),
                    LinearLayout.LayoutParams.MATCH_PARENT);
            colorStrip.setLayoutParams(stripParams);
            int color = group.isEmpty() ? Color.parseColor("#FFB0BEC5")
                    : colorForEvento(group.get(0));
            colorStrip.setBackgroundColor(color);

            LinearLayout contentLayout = new LinearLayout(this);
            contentLayout.setOrientation(LinearLayout.VERTICAL);
            contentLayout.setPadding(dp(6), dp(6), dp(6), dp(6));
            LinearLayout.LayoutParams contentParams = new LinearLayout.LayoutParams(0,
                    LinearLayout.LayoutParams.MATCH_PARENT, 1f);
            contentLayout.setLayoutParams(contentParams);

            // Cabecera: hora en una línea y número de eventos en otra
            TextView txtHora = new TextView(this);
            txtHora.setText(group.get(0).getHoraPrevista(hours));
            txtHora.setTextSize(13f);
            txtHora.setTypeface(null, Typeface.BOLD);
            txtHora.setTextColor(Color.parseColor("#1A237E"));
            contentLayout.addView(txtHora);

            TextView txtCount = new TextView(this);
            txtCount.setText(group.size() + " eventos");
            txtCount.setTextSize(12f);
            txtCount.setTextColor(Color.parseColor("#455A64"));
            contentLayout.addView(txtCount);

            // Listado compacto de eventos, respetando una información por línea
            int maxVisible = 2; // menos eventos visibles para que quepan varias líneas por evento
            int count = 0;
            for (Evento ev : group) {
                if (count >= maxVisible)
                    break;

                LinearLayout itemLayout = new LinearLayout(this);
                itemLayout.setOrientation(LinearLayout.VERTICAL);
                LinearLayout.LayoutParams itemParams = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT);
                itemParams.topMargin = dp(2);
                itemLayout.setLayoutParams(itemParams);

                // Pedido
                TextView txtPedido = new TextView(this);
                String pedido = ev.pedido == null ? "" : ev.pedido.trim();
                txtPedido.setText("• " + pedido);
                txtPedido.setTextSize(13f);
                txtPedido.setTextColor(Color.parseColor("#212121"));
                txtPedido.setMaxLines(1);
                txtPedido.setEllipsize(TextUtils.TruncateAt.END);
                itemLayout.addView(txtPedido);

                // Cliente
                TextView txtCliente = new TextView(this);
                String cliente = ev.cliente == null ? "" : ev.cliente.trim();
                txtCliente.setText(cliente);
                txtCliente.setTextSize(12f);
                txtCliente.setTextColor(Color.parseColor("#212121"));
                txtCliente.setMaxLines(1);
                txtCliente.setEllipsize(TextUtils.TruncateAt.END);
                itemLayout.addView(txtCliente);

                // Equipo
                TextView txtEquipo = new TextView(this);
                String equipo = !TextUtils.isEmpty(ev.equipoCodigo)
                        ? "Equipo " + ev.equipoCodigo
                        : "Equipo n/d";
                txtEquipo.setText(equipo);
                txtEquipo.setTextSize(12f);
                txtEquipo.setTextColor(colorForEquipo(ev.equipoCodigo));
                txtEquipo.setMaxLines(1);
                txtEquipo.setEllipsize(TextUtils.TruncateAt.END);
                itemLayout.addView(txtEquipo);

                contentLayout.addView(itemLayout);
                count++;
            }

            if (group.size() > maxVisible) {
                TextView more = new TextView(this);
                int remaining = group.size() - maxVisible;
                more.setText("+ " + remaining + " eventos más");
                more.setTextSize(12f);
                more.setTextColor(Color.parseColor("#455A64"));
                contentLayout.addView(more);
            }

            container.addView(colorStrip);
            container.addView(contentLayout);

            styleEventCard(container, group.get(0).equipoCodigo);

            int availableWidth = cellWidth - dp(12);
            int left = baseCell.getLeft() + dp(6);

            // Altura ajustada estrictamente al bloque horario para evitar solapamientos
            int eventHeight = cellHeight * duration - dp(8);

            int top = (firstRow.getTop() + cellHeight * startHourIndex) + dp(4);

            FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                    availableWidth,
                    eventHeight);

            params.leftMargin = left;
            params.topMargin = top;

            // Al tocar el bloque agrupado, mostrar detalle completo de todos los eventos en
            // un diálogo personalizado
            container.setOnClickListener(v -> {
                View dialogView = getLayoutInflater().inflate(R.layout.dialog_events_group, null);
                TextView txtHoraGrupo = dialogView.findViewById(R.id.txtGrupoHora);
                LinearLayout list = dialogView.findViewById(R.id.listGrupoEventos);

                txtHoraGrupo.setText(group.get(0).getHoraPrevista(hours)
                        + " · " + group.size() + " eventos");

                for (Evento ev : group) {
                    View row = getLayoutInflater().inflate(R.layout.item_event_group_row, list, false);
                    TextView txtRowTitulo = row.findViewById(R.id.txtRowTitulo);
                    TextView txtRowInfo = row.findViewById(R.id.txtRowInfo);
                    Button btnDetalle = row.findViewById(R.id.btnRowDetalle);
                    View accentView = row.findViewById(R.id.viewRowAccent);

                    String pedido = UiText.sanitizeDbValue(ev.pedido);
                    String cliente = UiText.sanitizeDbValue(ev.cliente);
                    String titulo = pedido;
                    if (!cliente.isEmpty()) {
                        if (!titulo.isEmpty()) {
                            titulo += " · ";
                        }
                        titulo += cliente;
                    }
                    if (!TextUtils.isEmpty(ev.equipoCodigo)) {
                        titulo += " (Eq. " + ev.equipoCodigo + ")";
                    }
                    if (titulo.trim().isEmpty()) {
                        txtRowTitulo.setText(UiText.placeholderSpan("Sin título"));
                    } else {
                        txtRowTitulo.setText(titulo.trim());
                    }

                    StringBuilder info = new StringBuilder();
                    String dirLimpia = formatDireccion(ev.direccion);
                    String tel = UiText.sanitizeDbValue(ev.telefono);
                    String wa = UiText.sanitizeDbValue(ev.whatsapp);

                    if (!dirLimpia.isEmpty()) {
                        info.append("Dirección:\t").append(dirLimpia);
                    }
                    if (!tel.isEmpty()) {
                        if (info.length() > 0)
                            info.append("\n");
                        info.append("Teléfono:\t").append(tel);
                    }
                    if (!wa.isEmpty()) {
                        if (info.length() > 0)
                            info.append("\n");
                        info.append("WhatsApp:\t").append(wa);
                    }
                    if (info.length() == 0) {
                        txtRowInfo.setText(UiText.placeholderSpan("Datos de contacto no disponibles"));
                    } else {
                        txtRowInfo.setText(info.toString());
                    }

                    if (accentView != null) {
                        accentView.setBackgroundColor(colorForEvento(ev));
                    }

                    // Botón explícito para abrir la ficha del evento (solo si es pedido)
                    if (isPedidoValido(ev.pedido)) {
                        btnDetalle.setOnClickListener(v2 -> openEventDetail(ev));
                    } else {
                        btnDetalle.setText("Sin pedido");
                        btnDetalle.setEnabled(false);
                        btnDetalle.setAlpha(0.5f);
                    }

                    list.addView(row);
                }

                AlertDialog dialog = new AlertDialog.Builder(CalendarActivity.this, R.style.CalendarDialogTheme)
                        .setView(dialogView)
                        .create();
                dialog.show();
                if (dialog.getWindow() != null) {
                    dialog.getWindow().setLayout(
                            (int) (getResources().getDisplayMetrics().widthPixels * 0.94f),
                            WindowManager.LayoutParams.WRAP_CONTENT);
                }

                Button btnCerrarGrupo = dialogView.findViewById(R.id.btnCerrarGrupo);
                if (btnCerrarGrupo != null) {
                    btnCerrarGrupo.setOnClickListener(v2 -> dialog.dismiss());
                }
            });

            container.setAlpha(0f);
            calendarOverlay.addView(container, params);
            container.animate().alpha(1f).setDuration(200).start();
        });
    }

    private void styleEventCard(View card, String equipoCodigo) {
        this.equipoCodigo = equipoCodigo;
        card.setClickable(true);
        card.setFocusable(true);
        // Elevación suave tipo tarjeta
        card.setElevation(dp(2));

        // Ripple al pulsar, respetando el tema actual
        android.util.TypedValue outValue = new android.util.TypedValue();
        if (getTheme().resolveAttribute(android.R.attr.selectableItemBackground, outValue, true)) {
            card.setForeground(ContextCompat.getDrawable(this, outValue.resourceId));
        }
    }

    private boolean isToday(Calendar date) {
        if (date == null)
            return false;
        Calendar today = Calendar.getInstance();
        return date.get(Calendar.YEAR) == today.get(Calendar.YEAR)
                && date.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR);
    }

    private boolean isVisitaEvent(Evento ev) {
        if (ev == null)
            return false;
        StringBuilder sb = new StringBuilder();
        if (ev.titulo != null)
            sb.append(ev.titulo).append(" ");
        if (ev.detalles != null)
            sb.append(ev.detalles).append(" ");
        if (ev.comentarios != null)
            sb.append(ev.comentarios).append(" ");
        if (ev.pedido != null)
            sb.append(ev.pedido).append(" ");
        if (ev.cliente != null)
            sb.append(ev.cliente).append(" ");
        String text = sb.toString().toLowerCase(java.util.Locale.ROOT);
        return text.contains("visita");
    }

    private boolean pasaFiltros(Evento ev) {
        // Filtro por equipo
        if (!filtrosEquipos.isEmpty()) {
            if (ev.equipoCodigo == null || ev.equipoCodigo.trim().isEmpty()) {
                return false;
            }
            String equipoEv = ev.equipoCodigo.trim().toUpperCase(java.util.Locale.ROOT);
            if (!filtrosEquipos.contains(equipoEv)) {
                return false;
            }
        }

        // Filtro por estado y tipo de evento
        if (!"Todos los estados".equalsIgnoreCase(filtroEstado)) {
            String estadoRaw = ev.estado == null ? "" : ev.estado.trim();
            String lower = estadoRaw.toLowerCase(java.util.Locale.ROOT);
            boolean esFinalizado = lower.contains("finalizado");
            boolean pedidoValido = isPedidoValido(ev.pedido);
            boolean esVisita = isVisitaEvent(ev);

            if ("Solo finalizados".equalsIgnoreCase(filtroEstado)) {
                if (!pedidoValido || !esFinalizado)
                    return false;
            } else if ("Solo sin finalizar".equalsIgnoreCase(filtroEstado)) {
                if (!pedidoValido || esFinalizado)
                    return false;
            } else if ("Solo eventos excepcionales".equalsIgnoreCase(filtroEstado)) {
                if (pedidoValido || esVisita)
                    return false;
            } else if ("Solo visitas".equalsIgnoreCase(filtroEstado)) {
                if (!esVisita)
                    return false;
            }
        }

        return true;
    }

    private void mostrarDialogoFiltrosEquipo() {
        final String[] equipos = new String[] { "FCB", "FCB2", "JZ", "JS", "MA", "CLM1" };
        boolean[] checked = new boolean[equipos.length];
        for (int i = 0; i < equipos.length; i++) {
            checked[i] = filtrosEquipos.contains(equipos[i]);
        }

        new AlertDialog.Builder(this)
                .setTitle("Filtrar por equipos")
                .setMultiChoiceItems(equipos, checked, (dialog, which, isChecked) -> {
                    String code = equipos[which];
                    if (isChecked) {
                        filtrosEquipos.add(code);
                    } else {
                        filtrosEquipos.remove(code);
                    }
                })
                .setPositiveButton("Aplicar", (dialog, which) -> {
                    actualizarEtiquetaFiltroEquipos();
                    refreshCalendar();
                })
                .setNeutralButton("Todos", (dialog, which) -> {
                    filtrosEquipos.clear();
                    actualizarEtiquetaFiltroEquipos();
                    refreshCalendar();
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void actualizarEtiquetaFiltroEquipos() {
        if (txtEquipoFilter == null)
            return;
        if (filtrosEquipos.isEmpty()) {
            txtEquipoFilter.setText("Todos los equipos");
        } else {
            StringBuilder sb = new StringBuilder();
            for (String code : filtrosEquipos) {
                if (sb.length() > 0)
                    sb.append(", ");
                sb.append(code);
            }
            txtEquipoFilter.setText(sb.toString());
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String readEquipoFromPrefs(SharedPreferences prefs) {
        if (prefs == null)
            return "";
        try {
            String value = prefs.getString("equipoInstaladores", "");
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
        } catch (ClassCastException ignored) {
        }
        return String.valueOf(prefs.getInt("equipoInstaladores", 0));
    }

    private boolean isPedidoValido(String pedido) {
        if (pedido == null)
            return false;
        String p = pedido.trim();
        if (p.isEmpty())
            return false;
        // Requiere al menos un número para considerar que es un pedido real
        return p.matches(".*\\d.*");
    }
}
