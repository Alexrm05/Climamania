package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;

import com.google.android.material.card.MaterialCardView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Locale;

public class IncidenciasPreviasActivity extends BaseActivity {

    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat(
            "yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat displayDateFormat = new SimpleDateFormat(
            "dd/MM/yyyy HH:mm", Locale.forLanguageTag("es-ES"));

    private TextView txtSaludo;
    private TextView txtMeta;
    private TextView txtLoading;
    private TextView txtEmpty;
    private LinearLayout listContainer;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_incidencias_previas, contentFrame, true);

        setupBottomBar();

        txtSaludo = content.findViewById(R.id.txtIncidenciasPreviasSaludo);
        txtMeta = content.findViewById(R.id.txtIncidenciasPreviasMeta);
        txtLoading = content.findViewById(R.id.txtIncidenciasPreviasLoading);
        txtEmpty = content.findViewById(R.id.txtIncidenciasPreviasEmpty);
        listContainer = content.findViewById(R.id.llIncidenciasPreviasList);
        Button btnVolver = content.findViewById(R.id.btnIncidenciasPreviasVolver);

        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        applyStaggeredEntrance(
                content.findViewById(R.id.txtIncidenciasPreviasSaludo),
                content.findViewById(R.id.txtIncidenciasPreviasTitulo),
                content.findViewById(R.id.txtIncidenciasPreviasMeta),
                content.findViewById(R.id.btnIncidenciasPreviasVolver));

        aplicarSaludoUsuario();
        renderIncidenciasFromExtras();
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

    private void renderIncidenciasFromExtras() {
        if (txtLoading != null) {
            txtLoading.setVisibility(View.GONE);
        }
        if (listContainer != null) {
            listContainer.removeAllViews();
        }

        String referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        String incidenciasJson = UiText.sanitizeDbValue(getIntent().getStringExtra("incidencias_json"));

        if (txtMeta != null) {
            StringBuilder meta = new StringBuilder("Listado de incidencias asociadas a la referencia");
            if (!referencia.isEmpty()) {
                meta.append(": ").append(referencia);
            }
            txtMeta.setText(meta.toString());
        }

        if (incidenciasJson.isEmpty()) {
            showEmpty("No hay incidencias previas.");
            return;
        }

        try {
            JSONArray incidencias = new JSONArray(incidenciasJson);
            if (incidencias.length() == 0) {
                showEmpty("No hay incidencias previas.");
                return;
            }

            if (txtEmpty != null) {
                txtEmpty.setVisibility(View.GONE);
            }
            for (int i = 0; i < incidencias.length(); i++) {
                JSONObject incidencia = incidencias.optJSONObject(i);
                if (incidencia == null) {
                    continue;
                }
                addIncidenciaRow(incidencia);
            }
            if (listContainer != null && listContainer.getChildCount() == 0) {
                showEmpty("No hay incidencias previas.");
            }
        } catch (Exception e) {
            showEmpty("No se pudieron leer las incidencias previas.");
        }
    }

    private void addIncidenciaRow(JSONObject incidencia) {
        if (listContainer == null) {
            return;
        }

        View row = getLayoutInflater().inflate(R.layout.item_visita_pendiente, listContainer, false);
        TextView txtEstado = row.findViewById(R.id.txtVisitaEstado);
        TextView txtCodigo = row.findViewById(R.id.txtVisitaCodigo);
        TextView txtCliente = row.findViewById(R.id.txtVisitaCliente);
        TextView txtPrioridad = row.findViewById(R.id.txtVisitaPrioridad);
        TextView txtDireccion = row.findViewById(R.id.txtVisitaDireccion);
        TextView txtMetaRow = row.findViewById(R.id.txtVisitaMeta);
        View btnMaps = row.findViewById(R.id.btnVisitaMaps);
        View btnLlamar = row.findViewById(R.id.btnVisitaLlamar);
        View btnMensaje = row.findViewById(R.id.btnVisitaMensaje);

        String idIncidencia = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_incidencia")));
        if (idIncidencia.isEmpty() || idIncidencia.equals("null")) {
            idIncidencia = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("id_visita")));
        }
        String referencia = UiText.sanitizeDbValue(
                incidencia.optString("referencia", incidencia.optString("pedido", "")));
        String cliente = UiText.sanitizeDbValue(incidencia.optString("cliente", ""));
        String direccion = UiText.sanitizeDbValue(incidencia.optString("direccion", ""));
        String poblacion = UiText.sanitizeDbValue(incidencia.optString("poblacion", ""));
        String equipoId = UiText.sanitizeDbValue(String.valueOf(incidencia.opt("equipo_id")));
        String fechaSolicitud = UiText.sanitizeDbValue(incidencia.optString("fecha_solicitud", ""));
        String solicitante = UiText.sanitizeDbValue(incidencia.optString("usuario_solicita", ""));
        String prioridadRaw = UiText.sanitizeDbValue(
                incidencia.optString("prioridad_label", incidencia.optString("prioridad", "")));

        PrioridadInfo prioridadInfo = parsePrioridad(prioridadRaw);

        if (txtEstado != null) {
            txtEstado.setText("Incidencia previa");
        }
        if (txtCodigo != null) {
            String codigo = referencia.isEmpty() ? (idIncidencia.isEmpty() ? "N/D" : idIncidencia) : referencia;
            txtCodigo.setText(codigo + " -");
        }
        if (txtCliente != null) {
            txtCliente.setText((cliente.isEmpty() ? "CLIENTE NO DISPONIBLE" : cliente).toUpperCase(Locale.ROOT));
        }
        if (txtPrioridad != null) {
            txtPrioridad.setText(prioridadInfo.label);
            txtPrioridad.setBackgroundResource(prioridadInfo.backgroundRes);
            txtPrioridad.setTextColor(prioridadInfo.textColor);
        }
        if (txtDireccion != null) {
            txtDireccion.setText("Dirección: " + buildDireccion(direccion, poblacion));
        }
        if (txtMetaRow != null) {
            String equipoText = equipoId.isEmpty() || equipoId.equals("null") ? "N/D" : equipoId;
            String solicitaText = solicitante.isEmpty() ? "N/D" : solicitante;
            txtMetaRow.setText(
                    "Equipo " + equipoText
                            + "  •  Solicita " + solicitaText
                            + "  •  " + formatFecha(fechaSolicitud));
        }

        if (row instanceof MaterialCardView) {
            ((MaterialCardView) row).setStrokeColor(resolvePriorityStrokeColor(prioridadInfo.label));
        }
        if (btnMaps != null) btnMaps.setVisibility(View.GONE);
        if (btnLlamar != null) btnLlamar.setVisibility(View.GONE);
        if (btnMensaje != null) btnMensaje.setVisibility(View.GONE);

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

    private void showEmpty(String message) {
        if (txtEmpty != null) {
            txtEmpty.setText(message);
            txtEmpty.setVisibility(View.VISIBLE);
        }
        if (listContainer != null) {
            listContainer.removeAllViews();
        }
    }

    private String buildDireccion(String direccion, String poblacion) {
        String dir = UiText.sanitizeDbValue(direccion);
        String pob = UiText.sanitizeDbValue(poblacion);
        if (dir.isEmpty()) {
            return pob.isEmpty() ? "No disponible" : pob;
        }
        if (pob.isEmpty()) {
            return dir;
        }
        return dir + " - " + pob;
    }

    private String formatFecha(String raw) {
        String clean = UiText.sanitizeDbValue(raw);
        if (clean.isEmpty()) {
            return "Sin fecha";
        }
        try {
            java.util.Date parsed = serverDateFormat.parse(clean);
            if (parsed == null) {
                return clean;
            }
            return displayDateFormat.format(parsed);
        } catch (ParseException e) {
            return clean;
        }
    }

    private int resolvePriorityStrokeColor(String prioridad) {
        String label = UiText.sanitizeDbValue(prioridad).toLowerCase(Locale.ROOT);
        if (label.equals("alta")) {
            return Color.parseColor("#F59E0B");
        }
        if (label.equals("media")) {
            return Color.parseColor("#0284C7");
        }
        return Color.parseColor("#D6C4B2");
    }

    private PrioridadInfo parsePrioridad(String raw) {
        String value = UiText.sanitizeDbValue(raw).toLowerCase(Locale.ROOT);
        if (value.equals("alta") || value.equals("high") || value.equals("urgente")) {
            return new PrioridadInfo("Alta", R.drawable.bg_priority_high, Color.WHITE);
        }
        if (value.equals("media") || value.equals("medio") || value.equals("normal")) {
            return new PrioridadInfo("Media", R.drawable.bg_priority_medium, Color.WHITE);
        }
        return new PrioridadInfo("Baja", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
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
                .setStartDelay(Math.min(index, 10) * 40L)
                .setDuration(220L)
                .setInterpolator(new android.view.animation.DecelerateInterpolator())
                .start();
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
