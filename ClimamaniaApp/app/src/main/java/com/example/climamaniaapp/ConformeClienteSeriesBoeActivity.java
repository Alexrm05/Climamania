package com.example.climamaniaapp;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;

import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import org.json.JSONArray;
import org.json.JSONObject;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class ConformeClienteSeriesBoeActivity extends BaseActivity {

    private static final String API_KEY = "TEST123";
    private static final String[] GET_URLS = new String[] {
            "https://app.clminstal.es/api/get_boe_equipos_revision.php",
            "https://app.clminstal.es/api/get_boe_equipos_revision.php",
            "https://clminstal.es/api/get_boe_equipos_revision.php",
            "https://clminstal.es/api/get_boe_equipos_revision.php"
    };
    private static final String[] SAVE_URLS = new String[] {
            "https://app.clminstal.es/api/guardar_boe_equipos_revision.php",
            "https://app.clminstal.es/api/guardar_boe_equipos_revision.php",
            "https://clminstal.es/api/guardar_boe_equipos_revision.php",
            "https://clminstal.es/api/guardar_boe_equipos_revision.php"
    };

    private RequestQueue requestQueue;

    private String referencia;
    private String cliente;
    private String pedidoJson;
    private boolean saving = false;

    private TextView txtReferencia;
    private TextView txtCliente;
    private TextView txtSource;
    private TextView txtEmpty;
    private LinearLayout llRows;
    private Button btnGuardar;

    private final List<SerieRow> rows = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(
                R.layout.content_conforme_cliente_series_boe,
                contentFrame,
                true
        );
        setupBottomBar();

        requestQueue = Volley.newRequestQueue(this);

        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));
        pedidoJson = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido_json"));

        txtReferencia = content.findViewById(R.id.txtConformeSeriesReferencia);
        txtCliente = content.findViewById(R.id.txtConformeSeriesCliente);
        txtSource = content.findViewById(R.id.txtConformeSeriesSource);
        txtEmpty = content.findViewById(R.id.txtConformeSeriesEmpty);
        llRows = content.findViewById(R.id.llConformeSeriesRows);
        Button btnAdd = content.findViewById(R.id.btnConformeSeriesAdd);
        btnGuardar = content.findViewById(R.id.btnConformeSeriesGuardar);
        Button btnVolver = content.findViewById(R.id.btnConformeSeriesVolver);

        UiText.setTextOrPlaceholder(txtReferencia, referencia, "Referencia no disponible");
        UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");

        if (btnAdd != null) {
            btnAdd.setOnClickListener(v -> {
                rows.add(new SerieRow("", ""));
                renderRows();
            });
        }
        if (btnGuardar != null) {
            btnGuardar.setOnClickListener(v -> guardarRevision());
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        if (referencia.isEmpty()) {
            Toast.makeText(this, "Referencia no disponible", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        cargarLineas(0, "");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (requestQueue != null) {
            requestQueue.cancelAll("boe_series_get");
            requestQueue.cancelAll("boe_series_save");
        }
    }

    private void cargarLineas(int index, String lastError) {
        if (index >= GET_URLS.length) {
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo cargar la revisión BOE";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            rows.clear();
            renderRows();
            return;
        }

        String url = GET_URLS[index]
                + "?api_key=" + urlEncode(API_KEY)
                + "&referencia=" + urlEncode(referencia)
                + "&_ts=" + System.currentTimeMillis();

        StringRequest request = new StringRequest(
                Request.Method.GET,
                url,
                response -> {
                    String parseError = handleGetResponse(response);
                    if (parseError != null) {
                        cargarLineas(index + 1, parseError);
                    }
                },
                error -> cargarLineas(index + 1, buildVolleyErrorMessage(error, "No se pudo cargar la revisión BOE"))
        );
        request.setShouldCache(false);
        request.setTag("boe_series_get");
        request.setRetryPolicy(new DefaultRetryPolicy(20000, 1, 1.0f));
        requestQueue.add(request);
    }

    @Nullable
    private String handleGetResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                return UiText.sanitizeDbValue(root.optString("message", "No se pudo cargar la revisión BOE"));
            }
            String source = UiText.sanitizeDbValue(root.optString("source", ""));
            if (txtSource != null) {
                if ("revision".equalsIgnoreCase(source)) {
                    txtSource.setText("Fuente: revisión guardada");
                } else {
                    txtSource.setText("Fuente: base del pedido");
                }
            }
            JSONArray lineas = root.optJSONArray("lineas");
            rows.clear();
            if (lineas != null) {
                for (int i = 0; i < lineas.length(); i++) {
                    JSONObject item = lineas.optJSONObject(i);
                    if (item == null) {
                        continue;
                    }
                    rows.add(new SerieRow(
                            UiText.sanitizeDbValue(item.optString("codigo", "")),
                            UiText.sanitizeDbValue(item.optString("num_serie", ""))
                    ));
                }
            }
            renderRows();
            return null;
        } catch (Exception e) {
            return "Respuesta inválida del servidor";
        }
    }

    private void renderRows() {
        if (llRows == null) {
            return;
        }
        llRows.removeAllViews();
        if (rows.isEmpty()) {
            if (txtEmpty != null) {
                txtEmpty.setVisibility(View.VISIBLE);
            }
            return;
        }
        if (txtEmpty != null) {
            txtEmpty.setVisibility(View.GONE);
        }

        for (SerieRow rowData : rows) {
            View row = getLayoutInflater().inflate(R.layout.item_conforme_boe_equipo, llRows, false);
            EditText editCodigo = row.findViewById(R.id.editConformeBoeCodigo);
            EditText editNumSerie = row.findViewById(R.id.editConformeBoeNumSerie);
            Button btnEliminar = row.findViewById(R.id.btnConformeBoeEliminar);

            editCodigo.setText(rowData.codigo);
            editNumSerie.setText(rowData.numSerie);

            editCodigo.addTextChangedListener(new RowWatcher() {
                @Override
                public void afterTextChanged(Editable s) {
                    rowData.codigo = UiText.sanitizeDbValue(s != null ? s.toString() : "");
                }
            });
            editNumSerie.addTextChangedListener(new RowWatcher() {
                @Override
                public void afterTextChanged(Editable s) {
                    rowData.numSerie = UiText.sanitizeDbValue(s != null ? s.toString() : "");
                }
            });

            btnEliminar.setOnClickListener(v -> {
                rows.remove(rowData);
                renderRows();
            });

            llRows.addView(row);
        }
    }

    private void guardarRevision() {
        if (saving) {
            return;
        }
        JSONArray lineasJson = buildValidRowsPayload();
        if (lineasJson.length() == 0) {
            Toast.makeText(this, "Debe existir al menos un equipo con código", Toast.LENGTH_LONG).show();
            return;
        }
        String usuario = resolveUsuarioActual();
        setSavingState(true);
        guardarRevisionWithFallback(lineasJson, usuario, 0, "");
    }

    private JSONArray buildValidRowsPayload() {
        JSONArray arr = new JSONArray();
        int orden = 1;
        for (SerieRow row : rows) {
            String codigo = UiText.sanitizeDbValue(row.codigo);
            String numSerie = UiText.sanitizeDbValue(row.numSerie);
            if (codigo.isEmpty() && numSerie.isEmpty()) {
                continue;
            }
            if (codigo.isEmpty()) {
                continue;
            }
            try {
                JSONObject item = new JSONObject();
                item.put("orden_linea", orden);
                item.put("codigo", codigo);
                item.put("num_serie", numSerie);
                arr.put(item);
                orden++;
            } catch (Exception ignored) {
                // Ignorar fila corrupta.
            }
        }
        return arr;
    }

    private void guardarRevisionWithFallback(JSONArray lineasJson, String usuario, int index, String lastError) {
        if (index >= SAVE_URLS.length) {
            setSavingState(false);
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo guardar la revisión BOE";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            return;
        }

        StringRequest request = new StringRequest(
                Request.Method.POST,
                SAVE_URLS[index],
                response -> {
                    String parseError = handleSaveResponse(response);
                    if (parseError != null) {
                        guardarRevisionWithFallback(lineasJson, usuario, index + 1, parseError);
                    }
                },
                error -> guardarRevisionWithFallback(
                        lineasJson,
                        usuario,
                        index + 1,
                        buildVolleyErrorMessage(error, "No se pudo guardar la revisión BOE")
                )
        ) {
            @Override
            protected java.util.Map<String, String> getParams() {
                java.util.Map<String, String> params = new java.util.HashMap<>();
                params.put("api_key", API_KEY);
                params.put("referencia", referencia);
                params.put("usuario", usuario);
                params.put("lineas_json", lineasJson.toString());
                return params;
            }
        };
        request.setShouldCache(false);
        request.setTag("boe_series_save");
        request.setRetryPolicy(new DefaultRetryPolicy(20000, 1, 1.0f));
        requestQueue.add(request);
    }

    @Nullable
    private String handleSaveResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                return UiText.sanitizeDbValue(root.optString("message", "No se pudo guardar la revisión BOE"));
            }
            setSavingState(false);
            Toast.makeText(this, UiText.sanitizeDbValue(root.optString("message", "Revisión BOE guardada")), Toast.LENGTH_LONG).show();
            Intent result = new Intent();
            result.putExtra("referencia", referencia);
            result.putExtra("cliente", cliente);
            if (!pedidoJson.isEmpty()) {
                result.putExtra("pedido_json", pedidoJson);
            }
            result.putExtra("requiere_boe", true);
            result.putExtra("revision_boe_guardada", true);
            setResult(Activity.RESULT_OK, result);
            finish();
            return null;
        } catch (Exception e) {
            return "Respuesta inválida del servidor";
        }
    }

    private void setSavingState(boolean value) {
        saving = value;
        if (btnGuardar != null) {
            btnGuardar.setEnabled(!value);
            btnGuardar.setText(value ? "Guardando..." : "Guardar y continuar");
        }
    }

    private String resolveUsuarioActual() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        if (!nombre.isEmpty()) {
            return nombre;
        }
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (!usuario.isEmpty()) {
            return usuario;
        }
        return UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
    }

    private String urlEncode(String value) {
        try {
            return java.net.URLEncoder.encode(value, "UTF-8");
        } catch (Exception e) {
            return "";
        }
    }

    private String buildVolleyErrorMessage(com.android.volley.VolleyError error, String fallback) {
        if (error == null) {
            return fallback;
        }
        if (error.networkResponse != null && error.networkResponse.data != null) {
            String body = new String(error.networkResponse.data, StandardCharsets.UTF_8).trim();
            if (!body.isEmpty()) {
                return body;
            }
            return "Error HTTP " + error.networkResponse.statusCode;
        }
        String msg = error.getMessage();
        if (msg != null && !msg.trim().isEmpty()) {
            return msg.trim();
        }
        return fallback;
    }

    private abstract static class RowWatcher implements TextWatcher {
        @Override
        public void beforeTextChanged(CharSequence s, int start, int count, int after) {
        }

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
        }
    }

    private static final class SerieRow {
        String codigo;
        String numSerie;

        SerieRow(String codigo, String numSerie) {
            this.codigo = codigo != null ? codigo : "";
            this.numSerie = numSerie != null ? numSerie : "";
        }
    }
}
