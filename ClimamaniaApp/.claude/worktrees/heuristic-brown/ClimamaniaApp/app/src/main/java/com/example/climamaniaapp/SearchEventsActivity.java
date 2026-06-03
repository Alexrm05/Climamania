package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
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
import java.util.Date;
import java.util.Locale;

/**
 * Pantalla de búsqueda de eventos.
 * Permite buscar por cualquier dato significativo del evento (pedido, cliente,
 * dirección, teléfono, equipo, etc.).
 */
public class SearchEventsActivity extends BaseActivity {

    private static final String EVENTS_URL = "https://app.clminstal.es/api/get_events.php";
    private static final String API_KEY = "TEST123";

    private EditText editSearchQuery;
    private TextView txtSearchStatus;
    private LinearLayout listSearchResults;

    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat dayFormat = new SimpleDateFormat("EEE d MMM", Locale.forLanguageTag("es-ES"));
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_search_events, contentFrame, true);

        setupBottomBar();

        editSearchQuery = content.findViewById(R.id.editSearchQuery);
        txtSearchStatus = content.findViewById(R.id.txtSearchStatus);
        listSearchResults = content.findViewById(R.id.listSearchResults);
        Button btnSearch = content.findViewById(R.id.btnSearchEvents);
        View btnBack = content.findViewById(R.id.btnBackSearch);

        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        // Si venimos con una búsqueda desde la página principal, la rellenamos
        String initialQuery = getIntent().getStringExtra("query");
        if (initialQuery != null && !initialQuery.trim().isEmpty()) {
            editSearchQuery.setText(initialQuery.trim());
            buscarEventos(initialQuery.trim());
        }

        btnSearch.setOnClickListener(v -> {
            String query = editSearchQuery.getText().toString().trim();
            if (query.isEmpty()) {
                Toast.makeText(this, "Introduce un dato del evento para buscar", Toast.LENGTH_SHORT).show();
                return;
            }
            buscarEventos(query);
        });
    }

    private void buscarEventos(String query) {
        txtSearchStatus.setText("Buscando eventos...");
        listSearchResults.removeAllViews();

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = prefs.getString("rol", "");
        String usuario = prefs.getString("usuario", "");
        String equipoStr = readEquipoFromPrefs(prefs);

        try {
            String url = EVENTS_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipoStr, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8");

            RequestQueue queue = Volley.newRequestQueue(this);

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> handleSearchResponse(response, query),
                    error -> {
                        String msg;
                        if (error.networkResponse != null) {
                            int statusCode = error.networkResponse.statusCode;
                            msg = "Error al cargar eventos (HTTP " + statusCode + ")";
                        } else {
                            msg = "Error de conexión al buscar eventos";
                        }
                        Log.e("SearchEventsActivity", "Volley error al buscar eventos", error);
                        txtSearchStatus.setText(msg);
                        Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                    });

            queue.add(request);
        } catch (Exception e) {
            Log.e("SearchEventsActivity", "Error construyendo URL de búsqueda", e);
            txtSearchStatus.setText("Error interno al preparar la búsqueda");
        }
    }

    private void handleSearchResponse(String response, String query) {
        String queryLower = query.toLowerCase(Locale.ROOT);
        int totalMatches = 0;

        try {
            JSONObject root = new JSONObject(response);
            boolean success = root.optBoolean("success", false);
            if (!success) {
                String message = root.optString("message", "No se pudieron obtener eventos");
                txtSearchStatus.setText(message);
                return;
            }

            JSONArray eventos = root.optJSONArray("eventos");
            if (eventos == null || eventos.length() == 0) {
                txtSearchStatus.setText("No hay eventos disponibles");
                return;
            }

            for (int i = 0; i < eventos.length(); i++) {
                JSONObject evJson = eventos.getJSONObject(i);

                String referencia = UiText.sanitizeDbValue(evJson.optString("referencia", ""));
                String nombreCliente = UiText.sanitizeDbValue(evJson.optString("nombrecliente", ""));
                String direccion = UiText.sanitizeDbValue(evJson.optString("direccion", ""));
                String telefono = UiText.sanitizeDbValue(evJson.optString("telefono", ""));
                String whatsapp = UiText.sanitizeDbValue(evJson.optString("whatsapp", ""));
                String equipo = UiText.sanitizeDbValue(evJson.optString("equipo_instaladores", ""));
                String estado = UiText.sanitizeDbValue(evJson.optString("estado", ""));
                String detalles = UiText.sanitizeDbValue(evJson.optString("detalles", ""));
                String comentarios = UiText.sanitizeDbValue(evJson.optString("comentarios", ""));
                String emailEquipo = UiText.sanitizeDbValue(evJson.optString("EmailEquipo", ""));
                String colorHex = UiText.sanitizeDbValue(evJson.optString("color", ""));
                String title = UiText.sanitizeDbValue(evJson.optString("title", ""));
                String startStr = UiText.sanitizeDbValue(evJson.optString("start", ""));
                String endStr = UiText.sanitizeDbValue(evJson.optString("end", ""));

                String searchable = (referencia + " " + nombreCliente + " " + direccion + " "
                        + telefono + " " + whatsapp + " " + equipo + " " + estado + " "
                        + detalles + " " + comentarios + " " + emailEquipo + " " + title)
                        .toLowerCase(Locale.ROOT);

                if (!searchable.contains(queryLower)) {
                    continue;
                }

                totalMatches++;
                addResultRow(evJson, referencia, nombreCliente, direccion,
                        equipo, telefono, whatsapp, estado, colorHex, startStr, endStr);
            }

            if (totalMatches == 0) {
                txtSearchStatus.setText("No se encontraron eventos para \"" + query + "\"");
            } else if (totalMatches == 1) {
                txtSearchStatus.setText("1 evento encontrado");
            } else {
                txtSearchStatus.setText(totalMatches + " eventos encontrados");
            }
        } catch (JSONException e) {
            Log.e("SearchEventsActivity", "Error parseando respuesta de búsqueda: " + response, e);
            txtSearchStatus.setText("Error al leer los resultados de la búsqueda");
        }
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

    private void addResultRow(JSONObject evJson,
            String referencia,
            String nombreCliente,
            String direccion,
            String equipo,
            String telefono,
            String whatsapp,
            String estado,
            String colorHex,
            String startStr,
            String endStr) {

        View row = getLayoutInflater().inflate(R.layout.item_search_event, listSearchResults, false);

        TextView txtTitle = row.findViewById(R.id.txtSearchTitle);
        TextView txtSub = row.findViewById(R.id.txtSearchSubtitle);
        TextView txtAddress = row.findViewById(R.id.txtSearchAddress);
        TextView txtEquipo = row.findViewById(R.id.txtSearchEquipo);

        // Título: pedido + cliente
        String refClean = UiText.sanitizeDbValue(referencia);
        String clienteClean = UiText.sanitizeDbValue(nombreCliente);
        StringBuilder title = new StringBuilder();
        if (!refClean.isEmpty()) {
            title.append(refClean);
        }
        if (!clienteClean.isEmpty()) {
            if (title.length() > 0)
                title.append(" · ");
            title.append(clienteClean);
        }
        if (title.length() == 0) {
            txtTitle.setText(UiText.placeholderSpan("Sin título"));
        } else {
            txtTitle.setText(title.toString());
        }

        // Subtítulo: fecha y franja horaria
        String fechaHora = buildFechaHora(startStr, endStr);
        String estadoVisual = buildEstadoLabel(UiText.sanitizeDbValue(estado));
        if (!estadoVisual.isEmpty()) {
            txtSub.setText(fechaHora + " · " + estadoVisual);
        } else {
            txtSub.setText(fechaHora);
        }

        // Dirección + teléfonos, con tabulador entre etiqueta y valor
        StringBuilder addressLine = new StringBuilder();
        String dirClean = limpiarDireccion(UiText.sanitizeDbValue(direccion));
        String telClean = UiText.sanitizeDbValue(telefono);
        String waClean = UiText.sanitizeDbValue(whatsapp);

        if (!dirClean.isEmpty()) {
            addressLine.append("Dirección:\t").append(dirClean);
        }
        if (!telClean.isEmpty()) {
            if (addressLine.length() > 0)
                addressLine.append("\n");
            addressLine.append("Teléfono:\t").append(telClean);
        }
        if (!waClean.isEmpty()) {
            if (addressLine.length() > 0)
                addressLine.append("\n");
            addressLine.append("WhatsApp:\t").append(waClean);
        }
        if (addressLine.length() == 0) {
            txtAddress.setText(UiText.placeholderSpan("Datos de contacto no disponibles"));
        } else {
            txtAddress.setText(addressLine.toString());
        }

        // Equipo
        String equipoClean = UiText.sanitizeDbValue(equipo);
        if (!equipoClean.isEmpty()) {
            txtEquipo.setText("Equipo " + equipoClean);
            txtEquipo.setTextColor(colorForEquipo(equipoClean));
        } else {
            txtEquipo.setText(UiText.placeholderSpan("Equipo no asignado"));
            txtEquipo.setTextColor(Color.parseColor("#757575"));
        }

        // Color de acento en el borde, si viene informado
        applyResultCardColor(row, UiText.sanitizeDbValue(colorHex), equipoClean);

        row.setOnClickListener(v -> openEventDetail(evJson, fechaHora));

        listSearchResults.addView(row);
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
            Date end;
            if (!endClean.isEmpty()) {
                end = serverDateFormat.parse(endClean);
            } else {
                end = null;
            }

            String fecha = dayFormat.format(start);
            String inicio = timeFormat.format(start);
            String rango;
            if (end != null) {
                String fin = timeFormat.format(end);
                rango = inicio + " - " + fin;
            } else {
                rango = inicio;
            }
            return fecha + " · " + rango;
        } catch (ParseException e) {
            return startClean;
        }
    }

    private String buildEstadoLabel(String estadoRaw) {
        String clean = UiText.sanitizeDbValue(estadoRaw);
        if (clean.isEmpty())
            return "";
        String lower = clean.toLowerCase(Locale.ROOT);
        boolean finalizado = lower.contains("finalizado");
        return finalizado ? "Finalizado" : "Sin finalizar";
    }

    private void applyResultCardColor(View row, String colorHex, String equipoCodigo) {
        int accentColor = colorForEquipo(equipoCodigo);
        if (colorHex != null && !colorHex.trim().isEmpty()) {
            String hex = colorHex.trim();
            if (!hex.startsWith("#"))
                hex = "#" + hex;
            try {
                accentColor = Color.parseColor(hex);
            } catch (IllegalArgumentException ignored) {
            }
        }

        View borderView = row.findViewById(R.id.searchCardBorder);
        if (borderView != null) {
            borderView.setBackgroundColor(accentColor);
        }
    }

    private void openEventDetail(JSONObject evJson, String horaFormateada) {
        Intent intent = new Intent(SearchEventsActivity.this, PedidoDetailActivity.class);

        String referencia = UiText.sanitizeDbValue(evJson.optString("referencia", ""));
        if (!isPedidoValido(referencia)) {
            Toast.makeText(this,
                    "Este evento no tiene pedido asociado",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        String nombreCliente = UiText.sanitizeDbValue(evJson.optString("nombrecliente", ""));
        String equipo = UiText.sanitizeDbValue(evJson.optString("equipo_instaladores", ""));
        String estado = UiText.sanitizeDbValue(evJson.optString("estado", ""));
        String direccionRaw = UiText.sanitizeDbValue(evJson.optString("direccion", ""));
        String direccion = limpiarDireccion(direccionRaw);
        String telefono = UiText.sanitizeDbValue(evJson.optString("telefono", ""));
        String whatsapp = UiText.sanitizeDbValue(evJson.optString("whatsapp", ""));
        String detalles = UiText.sanitizeDbValue(evJson.optString("detalles", ""));
        String comentarios = UiText.sanitizeDbValue(evJson.optString("comentarios", ""));
        String concertada = UiText.sanitizeDbValue(evJson.optString("concertada", ""));
        String emailEquipo = UiText.sanitizeDbValue(evJson.optString("EmailEquipo", ""));
        String colorHex = UiText.sanitizeDbValue(evJson.optString("color", ""));

        intent.putExtra("referencia", referencia);
        if (nombreCliente != null) {
            intent.putExtra("cliente", nombreCliente);
        }

        startActivity(intent);
    }

    private boolean isPedidoValido(String pedido) {
        if (pedido == null)
            return false;
        String p = pedido.trim();
        if (p.isEmpty())
            return false;
        return p.matches(".*\\d.*");
    }

    private int colorForEquipo(String equipoCodigo) {
        if (equipoCodigo == null) {
            return Color.parseColor("#FFB0BEC5"); // gris claro
        }
        String code = equipoCodigo.trim().toUpperCase(Locale.ROOT);

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
            default:
                return Color.parseColor("#FFB0BEC5"); // gris claro
        }
    }
}
