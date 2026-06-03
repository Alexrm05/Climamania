package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class SearchEventsActivity extends BaseActivity {

    private static final String EVENTS_URL = "https://app.clminstal.es/api/get_events.php";
    private static final String VISITAS_URL = "https://app.clminstal.es/api/get_visitas_realizadas_busqueda.php";
    private static final String INCIDENCIAS_URL = "https://app.clminstal.es/api/get_incidencias_realizadas_busqueda.php";
    private static final String API_KEY = "TEST123";

    private static final int TYPE_EVENTO = 1;
    private static final int TYPE_VISITA = 2;
    private static final int TYPE_INCIDENCIA = 3;

    private EditText editSearchQuery;
    private TextView txtSearchStatus;
    private LinearLayout listSearchResults;
    private RequestQueue requestQueue;

    private final List<JSONObject> matchedEventos = new ArrayList<>();
    private final List<JSONObject> matchedVisitas = new ArrayList<>();
    private final List<JSONObject> matchedIncidencias = new ArrayList<>();

    private int activeSearchToken = 0;
    private int pendingSearchSources = 0;
    private boolean hasSourceError = false;

    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat dayFormat = new SimpleDateFormat("EEE d MMM", Locale.forLanguageTag("es-ES"));
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());
    private final SimpleDateFormat displayDateFormat = new SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.forLanguageTag("es-ES"));

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_search_events, contentFrame, true);

        setupBottomBar();
        requestQueue = Volley.newRequestQueue(this);

        editSearchQuery = content.findViewById(R.id.editSearchQuery);
        txtSearchStatus = content.findViewById(R.id.txtSearchStatus);
        listSearchResults = content.findViewById(R.id.listSearchResults);
        Button btnSearch = content.findViewById(R.id.btnSearchEvents);
        View btnBack = content.findViewById(R.id.btnBackSearch);

        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        String initialQuery = getIntent().getStringExtra("query");
        if (initialQuery != null && !initialQuery.trim().isEmpty()) {
            editSearchQuery.setText(initialQuery.trim());
            buscarResultados(initialQuery.trim());
        }

        if (btnSearch != null) {
            btnSearch.setOnClickListener(v -> {
                String query = editSearchQuery.getText().toString().trim();
                if (query.isEmpty()) {
                    Toast.makeText(this, "Introduce un dato para buscar", Toast.LENGTH_SHORT).show();
                    return;
                }
                buscarResultados(query);
            });
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (requestQueue != null) {
            requestQueue.cancelAll("search_results");
        }
    }

    private void buscarResultados(String query) {
        activeSearchToken++;
        int token = activeSearchToken;

        matchedEventos.clear();
        matchedVisitas.clear();
        matchedIncidencias.clear();
        pendingSearchSources = 3;
        hasSourceError = false;

        txtSearchStatus.setText("Buscando eventos, visitas e incidencias...");
        listSearchResults.removeAllViews();

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipo = readEquipoFromPrefs(prefs);

        try {
            String commonParams = "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipo, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            loadSource(token, EVENTS_URL + commonParams,
                    response -> handleEventosResponse(token, response, query),
                    error -> handleSourceError(token, "Error al cargar eventos", error));

            loadSource(token, VISITAS_URL + commonParams,
                    response -> handleVisitasResponse(token, response, query),
                    error -> handleSourceError(token, "Error al cargar visitas", error));

            loadSource(token, INCIDENCIAS_URL + commonParams,
                    response -> handleIncidenciasResponse(token, response, query),
                    error -> handleSourceError(token, "Error al cargar incidencias", error));
        } catch (Exception e) {
            Log.e("SearchEventsActivity", "Error construyendo búsqueda", e);
            txtSearchStatus.setText("Error interno al preparar la búsqueda");
        }
    }

    private void loadSource(
            int token,
            String url,
            com.android.volley.Response.Listener<String> listener,
            com.android.volley.Response.ErrorListener errorListener
    ) {
        if (requestQueue == null) {
            requestQueue = Volley.newRequestQueue(this);
        }
        StringRequest request = new StringRequest(Request.Method.GET, url, listener, errorListener);
        request.setShouldCache(false);
        request.setTag("search_results");
        requestQueue.add(request);
    }

    private void handleEventosResponse(int token, String response, String query) {
        if (token != activeSearchToken) {
            return;
        }

        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                hasSourceError = true;
                completeSearchSource(token, query);
                return;
            }

            JSONArray eventos = root.optJSONArray("eventos");
            matchedEventos.clear();
            if (eventos != null) {
                String queryLower = query.toLowerCase(Locale.ROOT);
                for (int i = 0; i < eventos.length(); i++) {
                    JSONObject evJson = eventos.optJSONObject(i);
                    if (evJson == null) {
                        continue;
                    }
                    if (matchesEvento(evJson, queryLower)) {
                        matchedEventos.add(evJson);
                    }
                }
            }
        } catch (JSONException e) {
            Log.e("SearchEventsActivity", "Error parseando eventos", e);
            hasSourceError = true;
        }

        completeSearchSource(token, query);
    }

    private void handleVisitasResponse(int token, String response, String query) {
        if (token != activeSearchToken) {
            return;
        }

        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                hasSourceError = true;
                completeSearchSource(token, query);
                return;
            }

            JSONArray visitas = root.optJSONArray("visitas");
            matchedVisitas.clear();
            if (visitas != null) {
                String queryLower = query.toLowerCase(Locale.ROOT);
                for (int i = 0; i < visitas.length(); i++) {
                    JSONObject visita = visitas.optJSONObject(i);
                    if (visita == null) {
                        continue;
                    }
                    if (matchesVisita(visita, queryLower)) {
                        matchedVisitas.add(visita);
                    }
                }
            }
        } catch (JSONException e) {
            Log.e("SearchEventsActivity", "Error parseando visitas", e);
            hasSourceError = true;
        }

        completeSearchSource(token, query);
    }

    private void handleIncidenciasResponse(int token, String response, String query) {
        if (token != activeSearchToken) {
            return;
        }

        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                hasSourceError = true;
                completeSearchSource(token, query);
                return;
            }

            JSONArray incidencias = root.optJSONArray("incidencias");
            matchedIncidencias.clear();
            if (incidencias != null) {
                String queryLower = query.toLowerCase(Locale.ROOT);
                for (int i = 0; i < incidencias.length(); i++) {
                    JSONObject incidencia = incidencias.optJSONObject(i);
                    if (incidencia == null) {
                        continue;
                    }
                    if (matchesIncidencia(incidencia, queryLower)) {
                        matchedIncidencias.add(incidencia);
                    }
                }
            }
        } catch (JSONException e) {
            Log.e("SearchEventsActivity", "Error parseando incidencias", e);
            hasSourceError = true;
        }

        completeSearchSource(token, query);
    }

    private void handleSourceError(int token, String message, com.android.volley.VolleyError error) {
        if (token != activeSearchToken) {
            return;
        }
        Log.e("SearchEventsActivity", message, error);
        hasSourceError = true;
        completeSearchSource(token, editSearchQuery != null ? editSearchQuery.getText().toString().trim() : "");
    }

    private void completeSearchSource(int token, String query) {
        if (token != activeSearchToken) {
            return;
        }
        pendingSearchSources--;
        if (pendingSearchSources <= 0) {
            renderResults(query);
        }
    }

    private void renderResults(String query) {
        listSearchResults.removeAllViews();

        int totalMatches = matchedEventos.size() + matchedVisitas.size() + matchedIncidencias.size();
        if (hasSourceError) {
            if (totalMatches == 0) {
                txtSearchStatus.setText("No se pudieron cargar todos los resultados de búsqueda");
            } else {
                txtSearchStatus.setText(totalMatches + " resultados encontrados (parciales)");
            }
        } else if (totalMatches == 0) {
            txtSearchStatus.setText("No se encontraron resultados para \"" + query + "\"");
        } else if (totalMatches == 1) {
            txtSearchStatus.setText("1 resultado encontrado");
        } else {
            txtSearchStatus.setText(totalMatches + " resultados encontrados");
        }

        addSection("Eventos", matchedEventos, TYPE_EVENTO);
        addSection("Visitas", matchedVisitas, TYPE_VISITA);
        addSection("Incidencias", matchedIncidencias, TYPE_INCIDENCIA);
    }

    private void addSection(String title, List<JSONObject> items, int type) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams sectionParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        sectionParams.bottomMargin = dp(14);
        section.setLayoutParams(sectionParams);

        TextView header = new TextView(this);
        header.setText(title + " (" + items.size() + ")");
        header.setTextColor(Color.parseColor("#5D4037"));
        header.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f);
        header.setTypeface(null, android.graphics.Typeface.BOLD);
        header.setPadding(0, 0, 0, dp(8));
        section.addView(header);

        if (items.isEmpty()) {
            TextView empty = new TextView(this);
            empty.setText("Sin resultados");
            empty.setTextColor(Color.parseColor("#607D8B"));
            empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
            empty.setBackgroundResource(R.drawable.bg_chip_light);
            empty.setPadding(dp(10), dp(8), dp(10), dp(8));
            section.addView(empty);
        } else {
            for (JSONObject item : items) {
                View row = buildResultRow(item, type);
                if (row != null) {
                    section.addView(row);
                }
            }
        }

        listSearchResults.addView(section);
    }

    private View buildResultRow(JSONObject item, int type) {
        View row = getLayoutInflater().inflate(R.layout.item_search_event, listSearchResults, false);

        TextView txtTitle = row.findViewById(R.id.txtSearchTitle);
        TextView txtSub = row.findViewById(R.id.txtSearchSubtitle);
        TextView txtAddress = row.findViewById(R.id.txtSearchAddress);
        TextView txtMeta = row.findViewById(R.id.txtSearchEquipo);

        if (type == TYPE_EVENTO) {
            bindEventoRow(row, item, txtTitle, txtSub, txtAddress, txtMeta);
        } else if (type == TYPE_VISITA) {
            bindVisitaRow(row, item, txtTitle, txtSub, txtAddress, txtMeta);
        } else if (type == TYPE_INCIDENCIA) {
            bindIncidenciaRow(row, item, txtTitle, txtSub, txtAddress, txtMeta);
        }

        return row;
    }

    private void bindEventoRow(
            View row,
            JSONObject evJson,
            TextView txtTitle,
            TextView txtSub,
            TextView txtAddress,
            TextView txtMeta
    ) {
        String referencia = UiText.sanitizeDbValue(evJson.optString("referencia", ""));
        String nombreCliente = UiText.sanitizeDbValue(evJson.optString("nombrecliente", ""));
        String direccion = UiText.sanitizeDbValue(evJson.optString("direccion", ""));
        String telefono = UiText.sanitizeDbValue(evJson.optString("telefono", ""));
        String whatsapp = UiText.sanitizeDbValue(evJson.optString("whatsapp", ""));
        String equipo = UiText.sanitizeDbValue(evJson.optString("equipo_instaladores", ""));
        String estado = UiText.sanitizeDbValue(evJson.optString("estado", ""));
        String colorHex = UiText.sanitizeDbValue(evJson.optString("color", ""));
        String startStr = UiText.sanitizeDbValue(evJson.optString("start", ""));
        String endStr = UiText.sanitizeDbValue(evJson.optString("end", ""));

        StringBuilder title = new StringBuilder();
        if (!referencia.isEmpty()) {
            title.append(referencia);
        }
        if (!nombreCliente.isEmpty()) {
            if (title.length() > 0) {
                title.append(" · ");
            }
            title.append(nombreCliente);
        }
        txtTitle.setText(title.length() == 0 ? UiText.placeholderSpan("Sin título") : title.toString());

        String fechaHora = buildFechaHora(startStr, endStr);
        String estadoVisual = buildEstadoLabel(estado);
        String subtitle = "Evento";
        if (!fechaHora.isEmpty()) {
            subtitle += " · " + fechaHora;
        }
        if (!estadoVisual.isEmpty()) {
            subtitle += " · " + estadoVisual;
        }
        txtSub.setText(subtitle);

        txtAddress.setText(buildContactLine(limpiarDireccion(direccion), telefono, whatsapp, ""));

        if (!equipo.isEmpty()) {
            txtMeta.setText("Equipo " + equipo);
            txtMeta.setTextColor(colorForEquipo(equipo));
        } else {
            txtMeta.setText(UiText.placeholderSpan("Equipo no asignado"));
            txtMeta.setTextColor(Color.parseColor("#757575"));
        }

        applyResultCardColor(row, colorHex, equipo, TYPE_EVENTO);
        row.setOnClickListener(v -> openEventDetail(evJson));
    }

    private void bindVisitaRow(
            View row,
            JSONObject visita,
            TextView txtTitle,
            TextView txtSub,
            TextView txtAddress,
            TextView txtMeta
    ) {
        String idVisita = UiText.sanitizeDbValue(String.valueOf(visita.opt("id_visita")));
        String cliente = UiText.sanitizeDbValue(visita.optString("cliente", ""));
        String direccion = UiText.sanitizeDbValue(visita.optString("direccion", ""));
        String poblacion = UiText.sanitizeDbValue(visita.optString("poblacion", ""));
        String telefono = UiText.sanitizeDbValue(visita.optString("telefono", ""));
        String email = UiText.sanitizeDbValue(visita.optString("email", ""));
        String equipoId = UiText.sanitizeDbValue(String.valueOf(visita.opt("equipo_id")));
        String solicitante = UiText.sanitizeDbValue(visita.optString("usuario_solicita", ""));
        String prioridad = UiText.sanitizeDbValue(
                visita.optString("prioridad_label", visita.optString("prioridad", "")));
        String estado = UiText.sanitizeDbValue(
                visita.optString("estado_label", UiText.sanitizeDbValue(String.valueOf(visita.opt("estado")))));
        String fechaSolicitud = UiText.sanitizeDbValue(visita.optString("fecha_solicitud", ""));
        String fechaResolucion = UiText.sanitizeDbValue(visita.optString("fecha_resolucion", ""));

        StringBuilder title = new StringBuilder("Visita");
        if (!idVisita.isEmpty() && !idVisita.equals("null")) {
            title.append(" #").append(idVisita);
        }
        if (!cliente.isEmpty()) {
            title.append(" · ").append(cliente);
        }
        txtTitle.setText(title.toString());

        String estadoVisual = buildGestionStatusLabel(estado);
        String fechaVisual = "Pendiente".equals(estadoVisual) ? formatServerDate(fechaSolicitud)
                : (!fechaResolucion.isEmpty() ? formatServerDate(fechaResolucion) : formatServerDate(fechaSolicitud));
        txtSub.setText("Visita · " + estadoVisual + (fechaVisual.isEmpty() ? "" : " · " + fechaVisual));

        txtAddress.setText(buildContactLine(buildDireccion(direccion, poblacion), telefono, "", email));

        txtMeta.setText(buildMetaLine("Visita", prioridad, equipoId, solicitante));
        txtMeta.setTextColor(Color.parseColor("#0F766E"));

        applyResultCardColor(row, "", equipoId, TYPE_VISITA);
        row.setOnClickListener(v -> openVisitaDetail(idVisita));
    }

    private void bindIncidenciaRow(
            View row,
            JSONObject incidencia,
            TextView txtTitle,
            TextView txtSub,
            TextView txtAddress,
            TextView txtMeta
    ) {
        String idIncidencia = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_incidencia")));
        if (idIncidencia.isEmpty() || idIncidencia.equals("null")) {
            idIncidencia = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_visita")));
        }
        String referencia = UiText.sanitizeDbValue(
                incidencia.optString("referencia", incidencia.optString("pedido", "")));
        String cliente = UiText.sanitizeDbValue(incidencia.optString("cliente", ""));
        String direccion = UiText.sanitizeDbValue(incidencia.optString("direccion", ""));
        String poblacion = UiText.sanitizeDbValue(incidencia.optString("poblacion", ""));
        String telefono = UiText.sanitizeDbValue(incidencia.optString("telefono", ""));
        String email = UiText.sanitizeDbValue(incidencia.optString("email", ""));
        String equipoId = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("equipo_id")));
        String solicitante = UiText.sanitizeDbValue(incidencia.optString("usuario_solicita", ""));
        String prioridad = UiText.sanitizeDbValue(
                incidencia.optString("prioridad_label", incidencia.optString("prioridad", "")));
        String estado = UiText.sanitizeDbValue(
                incidencia.optString("estado_label", UiText.sanitizeDbValue(String.valueOf(incidencia.opt("estado")))));
        String fechaSolicitud = UiText.sanitizeDbValue(incidencia.optString("fecha_solicitud", ""));
        String fechaResolucion = UiText.sanitizeDbValue(incidencia.optString("fecha_resolucion", ""));

        StringBuilder title = new StringBuilder();
        if (!referencia.isEmpty()) {
            title.append(referencia);
        } else {
            title.append("Incidencia");
            if (!idIncidencia.isEmpty() && !idIncidencia.equals("null")) {
                title.append(" #").append(idIncidencia);
            }
        }
        if (!cliente.isEmpty()) {
            title.append(" · ").append(cliente);
        }
        txtTitle.setText(title.toString());

        String estadoVisual = buildGestionStatusLabel(estado);
        String fechaVisual = "Pendiente".equals(estadoVisual) ? formatServerDate(fechaSolicitud)
                : (!fechaResolucion.isEmpty() ? formatServerDate(fechaResolucion) : formatServerDate(fechaSolicitud));
        txtSub.setText("Incidencia · " + estadoVisual + (fechaVisual.isEmpty() ? "" : " · " + fechaVisual));

        txtAddress.setText(buildContactLine(buildDireccion(direccion, poblacion), telefono, "", email));

        txtMeta.setText(buildMetaLine("Incidencia", prioridad, equipoId, solicitante));
        txtMeta.setTextColor(Color.parseColor("#B45309"));

        applyResultCardColor(row, "", equipoId, TYPE_INCIDENCIA);
        final String idIncidenciaFinal = idIncidencia;
        final String referenciaFinal = referencia;
        row.setOnClickListener(v -> openIncidenciaDetail(idIncidenciaFinal, referenciaFinal));
    }

    private boolean matchesEvento(JSONObject evJson, String queryLower) {
        String searchable = (
                UiText.sanitizeDbValue(evJson.optString("referencia", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("nombrecliente", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("direccion", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("telefono", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("whatsapp", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("equipo_instaladores", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("estado", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("detalles", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("comentarios", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("EmailEquipo", "")) + " "
                        + UiText.sanitizeDbValue(evJson.optString("title", ""))
        ).toLowerCase(Locale.ROOT);
        return searchable.contains(queryLower);
    }

    private boolean matchesVisita(JSONObject visita, String queryLower) {
        String searchable = (
                UiText.sanitizeDbValue(String.valueOf(visita.opt("id_visita"))) + " "
                        + UiText.sanitizeDbValue(visita.optString("cliente", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("direccion", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("poblacion", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("telefono", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("email", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("prioridad", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("prioridad_label", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("estado", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("estado_label", "")) + " "
                        + UiText.sanitizeDbValue(String.valueOf(visita.opt("equipo_id"))) + " "
                        + UiText.sanitizeDbValue(visita.optString("usuario_solicita", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("fecha_solicitud", "")) + " "
                        + UiText.sanitizeDbValue(visita.optString("fecha_resolucion", ""))
        ).toLowerCase(Locale.ROOT);
        return searchable.contains(queryLower);
    }

    private boolean matchesIncidencia(JSONObject incidencia, String queryLower) {
        String searchable = (
                UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_incidencia"))) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("referencia", incidencia.optString("pedido", ""))) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("cliente", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("direccion", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("poblacion", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("telefono", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("email", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("prioridad", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("prioridad_label", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("estado", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("estado_label", "")) + " "
                        + UiText.sanitizeDbValue(String.valueOf(incidencia.opt("equipo_id"))) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("usuario_solicita", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("fecha_solicitud", "")) + " "
                        + UiText.sanitizeDbValue(incidencia.optString("fecha_resolucion", ""))
        ).toLowerCase(Locale.ROOT);
        return searchable.contains(queryLower);
    }

    private String readEquipoFromPrefs(SharedPreferences prefs) {
        if (prefs == null) {
            return "";
        }
        try {
            String value = prefs.getString("equipoInstaladores", "");
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
        } catch (ClassCastException ignored) {
        }
        return String.valueOf(prefs.getInt("equipoInstaladores", 0));
    }

    private String limpiarDireccion(String rawDireccion) {
        String raw = UiText.sanitizeDbValue(rawDireccion);
        raw = raw.replace("<br/>", "\n")
                .replace("<br />", "\n")
                .replace("<br>", "\n")
                .replace("<BR/>", "\n")
                .replace("<BR />", "\n")
                .replace("<BR>", "\n");
        raw = raw.replaceAll("<[^>]+>", "");
        return raw.trim();
    }

    private String buildFechaHora(String startStr, String endStr) {
        String startClean = UiText.sanitizeDbValue(startStr);
        String endClean = UiText.sanitizeDbValue(endStr);
        if (startClean.isEmpty()) {
            return "";
        }
        try {
            Date start = serverDateFormat.parse(startClean);
            Date end = endClean.isEmpty() ? null : serverDateFormat.parse(endClean);
            String fecha = dayFormat.format(start);
            String inicio = timeFormat.format(start);
            String rango = end != null ? inicio + " - " + timeFormat.format(end) : inicio;
            return fecha + " · " + rango;
        } catch (ParseException e) {
            return startClean;
        }
    }

    private String buildGestionStatusLabel(String estadoRaw) {
        String estado = UiText.sanitizeDbValue(estadoRaw).trim();
        if ("1".equals(estado) || "pendiente".equalsIgnoreCase(estado)) {
            return "Pendiente";
        }
        if (estado.isEmpty()) {
            return "Realizada";
        }
        return "Realizada";
    }

    private String buildEstadoLabel(String estadoRaw) {
        String clean = UiText.sanitizeDbValue(estadoRaw);
        if (clean.isEmpty()) {
            return "";
        }
        return clean.toLowerCase(Locale.ROOT).contains("finalizado") ? "Finalizado" : "Sin finalizar";
    }

    private String buildDireccion(String direccion, String poblacion) {
        String dir = UiText.sanitizeDbValue(direccion);
        String pob = UiText.sanitizeDbValue(poblacion);
        if (dir.isEmpty()) {
            return pob;
        }
        if (pob.isEmpty()) {
            return dir;
        }
        return dir + " - " + pob;
    }

    private String formatServerDate(String rawDate) {
        String clean = UiText.sanitizeDbValue(rawDate);
        if (clean.isEmpty()) {
            return "";
        }
        try {
            Date parsed = serverDateFormat.parse(clean);
            if (parsed == null) {
                return clean;
            }
            return displayDateFormat.format(parsed);
        } catch (ParseException e) {
            return clean;
        }
    }

    private String buildContactLine(String direccion, String telefono, String whatsapp, String email) {
        StringBuilder line = new StringBuilder();
        String dir = UiText.sanitizeDbValue(direccion);
        String tel = UiText.sanitizeDbValue(telefono);
        String wa = UiText.sanitizeDbValue(whatsapp);
        String mail = UiText.sanitizeDbValue(email);

        if (!dir.isEmpty()) {
            line.append("Dirección:\t").append(dir);
        }
        if (!tel.isEmpty()) {
            if (line.length() > 0) {
                line.append("\n");
            }
            line.append("Teléfono:\t").append(tel);
        }
        if (!wa.isEmpty()) {
            if (line.length() > 0) {
                line.append("\n");
            }
            line.append("WhatsApp:\t").append(wa);
        }
        if (!mail.isEmpty()) {
            if (line.length() > 0) {
                line.append("\n");
            }
            line.append("Email:\t").append(mail);
        }
        if (line.length() == 0) {
            return "Datos de contacto no disponibles";
        }
        return line.toString();
    }

    private String buildMetaLine(String tipo, String prioridad, String equipoId, String solicitante) {
        StringBuilder meta = new StringBuilder(tipo);
        String prioridadClean = UiText.sanitizeDbValue(prioridad);
        String equipoClean = UiText.sanitizeDbValue(equipoId);
        String solicitanteClean = UiText.sanitizeDbValue(solicitante);

        if (!prioridadClean.isEmpty()) {
            meta.append(" · Prioridad ").append(prioridadClean);
        }
        if (!equipoClean.isEmpty() && !equipoClean.equals("null")) {
            meta.append(" · Equipo ").append(equipoClean);
        }
        if (!solicitanteClean.isEmpty()) {
            meta.append(" · Solicita ").append(solicitanteClean);
        }
        return meta.toString();
    }

    private void applyResultCardColor(View row, String colorHex, String equipoCodigo, int type) {
        int accentColor;
        if (type == TYPE_EVENTO) {
            accentColor = colorForEquipo(equipoCodigo);
            if (!UiText.sanitizeDbValue(colorHex).isEmpty()) {
                String hex = colorHex.trim();
                if (!hex.startsWith("#")) {
                    hex = "#" + hex;
                }
                try {
                    accentColor = Color.parseColor(hex);
                } catch (IllegalArgumentException ignored) {
                }
            }
        } else if (type == TYPE_VISITA) {
            accentColor = Color.parseColor("#0F766E");
        } else {
            accentColor = Color.parseColor("#B45309");
        }

        View borderView = row.findViewById(R.id.searchCardBorder);
        if (borderView != null) {
            borderView.setBackgroundColor(accentColor);
        }
    }

    private void openEventDetail(JSONObject evJson) {
        String referencia = UiText.sanitizeDbValue(evJson.optString("referencia", ""));
        if (!isPedidoValido(referencia)) {
            Toast.makeText(this, "Este evento no tiene pedido asociado", Toast.LENGTH_SHORT).show();
            return;
        }

        Intent intent = new Intent(this, PedidoDetailActivity.class);
        intent.putExtra("referencia", referencia);

        String nombreCliente = UiText.sanitizeDbValue(evJson.optString("nombrecliente", ""));
        if (!nombreCliente.isEmpty()) {
            intent.putExtra("cliente", nombreCliente);
        }
        startActivity(intent);
    }

    private void openVisitaDetail(String idVisita) {
        String id = UiText.sanitizeDbValue(idVisita);
        if (id.isEmpty() || id.equals("null") || id.equals("0")) {
            Toast.makeText(this, "ID de visita no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, VisitaDetalleActivity.class);
        intent.putExtra("id_visita", id);
        startActivity(intent);
    }

    private void openIncidenciaDetail(String idIncidencia, String referencia) {
        String id = UiText.sanitizeDbValue(idIncidencia);
        if (id.isEmpty() || id.equals("null") || id.equals("0")) {
            Toast.makeText(this, "ID de incidencia no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, IncidenciaDetalleActivity.class);
        intent.putExtra("id_incidencia", id);
        if (!UiText.sanitizeDbValue(referencia).isEmpty()) {
            intent.putExtra("referencia", UiText.sanitizeDbValue(referencia));
        }
        startActivity(intent);
    }

    private boolean isPedidoValido(String pedido) {
        if (pedido == null) {
            return false;
        }
        String p = pedido.trim();
        return !p.isEmpty() && p.matches(".*\\d.*");
    }

    private int colorForEquipo(String equipoCodigo) {
        if (equipoCodigo == null) {
            return Color.parseColor("#FFB0BEC5");
        }
        String code = equipoCodigo.trim().toUpperCase(Locale.ROOT);
        switch (code) {
            case "FCB":
                return Color.parseColor("#FF1976D2");
            case "FCB2":
                return Color.parseColor("#FFE37D33");
            case "JZ":
                return Color.parseColor("#FF388E3C");
            case "JS":
                return Color.parseColor("#FF7B1FA2");
            case "MA":
                return Color.parseColor("#FF0097A7");
            case "CLM1":
                return Color.parseColor("#FFFBC02D");
            default:
                return Color.parseColor("#FFB0BEC5");
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
