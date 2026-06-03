package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.widget.ImageView;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.material.card.MaterialCardView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Locale;

public class IncidenciasPendientesActivity extends BaseActivity {

    private static final String INCIDENCIAS_PENDIENTES_DETALLE_URL =
            "https://app.clminstal.es/api/get_incidencias_pendientes_detalle.php";
    private static final String API_KEY = "TEST123";

    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat(
            "yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat displayDateFormat = new SimpleDateFormat(
            "dd/MM/yyyy HH:mm", Locale.forLanguageTag("es-ES"));

    private TextView txtSaludo;
    private TextView txtLoading;
    private TextView txtEmpty;
    private LinearLayout listContainer;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_visitas_pendientes, contentFrame, true);

        setupBottomBar();

        txtSaludo = content.findViewById(R.id.txtVisitasSaludo);
        txtLoading = content.findViewById(R.id.txtVisitasLoading);
        txtEmpty = content.findViewById(R.id.txtVisitasEmpty);
        listContainer = content.findViewById(R.id.llVisitasList);
        TextView txtSubtitulo = content.findViewById(R.id.txtVisitasSubtitulo);
        Button btnVolver = content.findViewById(R.id.btnVisitasVolver);
        View title = content.findViewById(R.id.txtVisitasTitulo);
        View orden = content.findViewById(R.id.txtVisitasOrden);

        if (txtSubtitulo != null) {
            txtSubtitulo.setText("Incidencias pendientes");
        }
        if (title instanceof TextView) {
            ((TextView) title).setText("Incidencias pendientes");
        }
        if (orden instanceof TextView) {
            ((TextView) orden).setText("Ordenadas por prioridad y fecha de solicitud");
        }

        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        applyStaggeredEntrance(txtSaludo, title, orden, txtLoading, btnVolver);

        aplicarSaludoUsuario();
        cargarIncidenciasPendientes();
    }

    private void aplicarSaludoUsuario() {
        if (txtSaludo == null) {
            return;
        }
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        String displayName = !nombre.isEmpty() ? nombre : (!usuario.isEmpty() ? usuario : "instalador");
        txtSaludo.setText("Hola " + displayName);
    }

    private void cargarIncidenciasPendientes() {
        if (txtLoading != null) {
            txtLoading.setVisibility(View.VISIBLE);
            txtLoading.setText("Cargando incidencias pendientes...");
        }
        if (txtEmpty != null) {
            txtEmpty.setVisibility(View.GONE);
        }
        if (listContainer != null) {
            listContainer.removeAllViews();
        }

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipo = readEquipoFromPrefs(prefs);

        try {
            String url = INCIDENCIAS_PENDIENTES_DETALLE_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipo, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();
            android.util.Log.d("IncidenciasPendientesActivity", "Detalle incidencias request rol=" + rol
                    + " usuario=" + usuario + " equipo=" + equipo);

            RequestQueue queue = Volley.newRequestQueue(this);
            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    this::handleIncidenciasResponse,
                    error -> showErrorState("No se pudieron cargar las incidencias pendientes"));
            request.setShouldCache(false);
            queue.add(request);
        } catch (Exception e) {
            showErrorState("No se pudieron cargar las incidencias pendientes");
        }
    }

    private void handleIncidenciasResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = UiText.sanitizeDbValue(root.optString("message", ""));
                if (message.isEmpty()) {
                    message = "No se pudieron cargar las incidencias pendientes";
                }
                showErrorState(message);
                return;
            }

            JSONArray incidencias = root.optJSONArray("incidencias");
            if (incidencias == null || incidencias.length() == 0) {
                showEmptyState("No tienes incidencias pendientes de realizar");
                return;
            }

            if (txtLoading != null) {
                txtLoading.setVisibility(View.GONE);
            }
            if (txtEmpty != null) {
                txtEmpty.setVisibility(View.GONE);
            }
            if (listContainer != null) {
                listContainer.removeAllViews();
            }

            for (int i = 0; i < incidencias.length(); i++) {
                JSONObject incidencia = incidencias.optJSONObject(i);
                if (incidencia == null) {
                    continue;
                }
                addIncidenciaRow(incidencia);
            }

            if (listContainer != null && listContainer.getChildCount() == 0) {
                showEmptyState("No tienes incidencias pendientes de realizar");
            }
        } catch (Exception e) {
            showErrorState("Respuesta invalida al cargar incidencias pendientes");
        }
    }

    private void addIncidenciaRow(JSONObject incidencia) {
        if (listContainer == null) {
            return;
        }

        View row = getLayoutInflater().inflate(R.layout.item_visita_pendiente, listContainer, false);
        TextView txtEstado = row.findViewById(R.id.txtVisitaEstado);
        ImageView imgEstado = row.findViewById(R.id.imgVisitaEstadoIcon);
        TextView txtCodigo = row.findViewById(R.id.txtVisitaCodigo);
        TextView txtCliente = row.findViewById(R.id.txtVisitaCliente);
        TextView txtPrioridad = row.findViewById(R.id.txtVisitaPrioridad);
        TextView txtDireccion = row.findViewById(R.id.txtVisitaDireccion);
        TextView txtMeta = row.findViewById(R.id.txtVisitaMeta);
        View btnMaps = row.findViewById(R.id.btnVisitaMaps);
        View btnLlamar = row.findViewById(R.id.btnVisitaLlamar);
        View btnMensaje = row.findViewById(R.id.btnVisitaMensaje);

        String cliente = UiText.sanitizeDbValue(incidencia.optString("cliente", ""));
        String direccion = UiText.sanitizeDbValue(incidencia.optString("direccion", ""));
        String poblacion = UiText.sanitizeDbValue(incidencia.optString("poblacion", ""));
        String telefono = UiText.sanitizeDbValue(incidencia.optString("telefono", ""));
        String idIncidencia = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_incidencia")));
        if (idIncidencia.isEmpty() || idIncidencia.equals("null")) {
            idIncidencia = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_visita")));
        }
        String referencia = UiText.sanitizeDbValue(
                incidencia.optString("referencia", incidencia.optString("pedido", "")));
        String equipoId = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("equipo_id")));
        String fechaSolicitud = UiText.sanitizeDbValue(incidencia.optString("fecha_solicitud", ""));
        String solicitante = UiText.sanitizeDbValue(incidencia.optString("usuario_solicita", ""));
        String prioridadRaw = UiText.sanitizeDbValue(
                incidencia.optString("prioridad_label", incidencia.optString("prioridad", "")));

        PrioridadInfo prioridadInfo = parsePrioridad(prioridadRaw);

        if (txtEstado != null) {
            txtEstado.setText("Incidencia pendiente");
        }
        if (imgEstado != null) {
            imgEstado.setImageResource(android.R.drawable.ic_dialog_alert);
        }
        String codigo = UiText.sanitizeDbValue(referencia);
        if (codigo.isEmpty()) {
            codigo = idIncidencia;
        }
        if (txtCodigo != null) {
            String codigoFinal = codigo.isEmpty() || codigo.equals("null") ? "N/D" : codigo;
            txtCodigo.setText(codigoFinal + " -");
        }
        txtCliente.setText((cliente.isEmpty() ? "CLIENTE NO DISPONIBLE" : cliente).toUpperCase(Locale.ROOT));
        txtPrioridad.setText(prioridadInfo.label);
        txtPrioridad.setBackgroundResource(prioridadInfo.backgroundRes);
        txtPrioridad.setTextColor(prioridadInfo.textColor);

        String direccionFinal = buildDireccion(direccion, poblacion);
        txtDireccion.setText("Dirección: " + (direccionFinal.isEmpty() ? "No disponible" : direccionFinal));
        String equipoText = equipoId.isEmpty() || equipoId.equals("null") ? "N/D" : equipoId;
        String solicitaText = solicitante.isEmpty() ? "N/D" : solicitante;
        txtMeta.setText("Equipo " + equipoText + "  •  Solicita " + solicitaText + "  •  " + formatFecha(fechaSolicitud));

        if (row instanceof MaterialCardView) {
            ((MaterialCardView) row).setStrokeColor(resolvePriorityStrokeColor(prioridadInfo.label));
        }

        final String direccionFinalRef = direccionFinal;
        final String telefonoFinal = telefono;
        final String clienteFinal = cliente;

        if (btnMaps != null) {
            btnMaps.setOnClickListener(v -> abrirMapa(direccionFinalRef));
        }
        if (btnLlamar != null) {
            btnLlamar.setOnClickListener(v -> llamarNumero(telefonoFinal));
        }
        if (btnMensaje != null) {
            btnMensaje.setOnClickListener(v -> abrirMensaje(telefonoFinal, clienteFinal));
        }

        final String idIncidenciaFinal = idIncidencia;
        final String referenciaFinal = referencia;
        row.setClickable(true);
        row.setFocusable(true);
        row.setOnClickListener(v -> abrirDetalleIncidencia(idIncidenciaFinal, referenciaFinal));

        listContainer.addView(row);
        animateRowEntrance(row, listContainer.getChildCount() - 1);
    }

    private void abrirDetalleIncidencia(String idIncidencia, String referencia) {
        String id = UiText.sanitizeDbValue(idIncidencia);
        if (id.isEmpty() || id.equals("null") || id.equals("0")) {
            android.widget.Toast.makeText(this, "ID de incidencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, IncidenciaDetalleActivity.class);
        intent.putExtra("id_incidencia", id);
        intent.putExtra("referencia", UiText.sanitizeDbValue(referencia));
        startActivity(intent);
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
        return dir + ", " + pob;
    }

    private String formatFecha(String rawDate) {
        String raw = UiText.sanitizeDbValue(rawDate);
        if (raw.isEmpty()) {
            return "No disponible";
        }
        try {
            java.util.Date parsed = serverDateFormat.parse(raw);
            if (parsed == null) {
                return raw;
            }
            return displayDateFormat.format(parsed);
        } catch (ParseException e) {
            return raw;
        }
    }

    private PrioridadInfo parsePrioridad(String raw) {
        String value = UiText.sanitizeDbValue(raw);
        if (value.isEmpty()) {
            return new PrioridadInfo("Sin prioridad", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
        }

        String lower = value.toLowerCase(Locale.ROOT);
        if (lower.equals("alta") || lower.equals("high") || lower.equals("urgente")) {
            return new PrioridadInfo("Alta", R.drawable.bg_priority_high, Color.WHITE);
        }
        if (lower.equals("media") || lower.equals("medio") || lower.equals("normal")) {
            return new PrioridadInfo("Media", R.drawable.bg_priority_medium, Color.WHITE);
        }
        if (lower.equals("baja") || lower.equals("low")) {
            return new PrioridadInfo("Baja", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
        }

        if (value.matches("\\d+")) {
            int n = Integer.parseInt(value);
            if (n >= 3) {
                return new PrioridadInfo("Alta", R.drawable.bg_priority_high, Color.WHITE);
            }
            if (n == 2) {
                return new PrioridadInfo("Media", R.drawable.bg_priority_medium, Color.WHITE);
            }
            return new PrioridadInfo("Baja", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
        }

        return new PrioridadInfo(value, R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
    }

    private int resolvePriorityStrokeColor(String prioridad) {
        String clean = UiText.sanitizeDbValue(prioridad).toLowerCase(Locale.ROOT);
        if (clean.equals("alta")) {
            return Color.parseColor("#F4B0A9");
        }
        if (clean.equals("media")) {
            return Color.parseColor("#F3D09B");
        }
        if (clean.equals("baja")) {
            return Color.parseColor("#CFD8DC");
        }
        return Color.parseColor("#E9DCCF");
    }

    private void animateRowEntrance(View row, int index) {
        if (row == null) {
            return;
        }
        row.setAlpha(0f);
        row.setTranslationY(dp(8));
        row.animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(Math.min(index, 10) * 45L)
                .setDuration(220L)
                .setInterpolator(new android.view.animation.DecelerateInterpolator())
                .start();
    }

    private void abrirMapa(String direccion) {
        String dir = UiText.sanitizeDbValue(direccion);
        if (dir.isEmpty()) {
            android.widget.Toast.makeText(this, "Direccion no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            Uri uri = Uri.parse("geo:0,0?q=" + Uri.encode(dir));
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            startActivity(intent);
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "No se pudo abrir Maps", android.widget.Toast.LENGTH_SHORT).show();
        }
    }

    private void llamarNumero(String telefono) {
        String tel = UiText.sanitizeDbValue(telefono);
        if (tel.isEmpty()) {
            android.widget.Toast.makeText(this, "Telefono no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            Intent intent = new Intent(Intent.ACTION_DIAL);
            intent.setData(Uri.parse("tel:" + tel));
            startActivity(intent);
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "No se pudo abrir el marcador", android.widget.Toast.LENGTH_SHORT).show();
        }
    }

    private void abrirMensaje(String telefono, String cliente) {
        String tel = UiText.sanitizeDbValue(telefono);
        if (tel.isEmpty()) {
            android.widget.Toast.makeText(this, "Telefono no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            Intent intent = new Intent(Intent.ACTION_SENDTO);
            intent.setData(Uri.parse("smsto:" + tel));
            String nombre = UiText.sanitizeDbValue(cliente);
            if (!nombre.isEmpty()) {
                intent.putExtra("sms_body", "Hola " + nombre + ", ");
            }
            startActivity(intent);
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "No se pudo abrir mensajes", android.widget.Toast.LENGTH_SHORT).show();
        }
    }

    private void applyStaggeredEntrance(View... views) {
        int delay = 50;
        int current = 0;
        for (View v : views) {
            if (v == null) {
                continue;
            }
            v.setAlpha(0f);
            v.setTranslationY(dp(6));
            v.animate()
                    .alpha(1f)
                    .translationY(0f)
                    .setDuration(220L)
                    .setStartDelay(current)
                    .setInterpolator(new android.view.animation.DecelerateInterpolator())
                    .start();
            current += delay;
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void showEmptyState(String message) {
        if (txtLoading != null) {
            txtLoading.setVisibility(View.GONE);
        }
        if (txtEmpty != null) {
            txtEmpty.setText(message);
            txtEmpty.setVisibility(View.VISIBLE);
        }
        if (listContainer != null) {
            listContainer.removeAllViews();
        }
    }

    private void showErrorState(String message) {
        if (txtLoading != null) {
            txtLoading.setText(message);
            txtLoading.setVisibility(View.VISIBLE);
        }
        if (txtEmpty != null) {
            txtEmpty.setVisibility(View.GONE);
        }
        if (listContainer != null) {
            listContainer.removeAllViews();
        }
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
            // Legacy int stored in prefs
        }
        return String.valueOf(prefs.getInt("equipoInstaladores", 0));
    }

    private static final class PrioridadInfo {
        final String label;
        final int backgroundRes;
        final int textColor;

        PrioridadInfo(String label, int backgroundRes, int textColor) {
            this.label = label;
            this.backgroundRes = backgroundRes;
            this.textColor = textColor;
        }
    }
}
