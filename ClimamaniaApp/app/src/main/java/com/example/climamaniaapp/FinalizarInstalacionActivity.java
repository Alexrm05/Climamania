package com.example.climamaniaapp;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.RatingBar;
import android.widget.TextView;

import androidx.annotation.Nullable;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.material.button.MaterialButton;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Map;

public class FinalizarInstalacionActivity extends BaseActivity {

    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String FINALIZAR_URL = "https://app.clminstal.es/api/finalizar_instalacion.php";
    private static final String API_KEY = "TEST123";

    private String referencia;
    private LinearLayout llFotosFaltantes;
    private TextView txtFinalizarReferencia;
    private EditText editCobroMetalico;
    private EditText editCobroVisa;
    private RadioGroup rgExtras;
    private RatingBar ratingSatisfaccion;
    private EditText editObservacionesFinales;
    private MaterialButton btnFinalizarAhora;
    private MaterialButton btnFinalizarVolver;
    private EventLocationCaptureHelper locationCaptureHelper;
    private boolean finalizando = false;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        View content = getLayoutInflater().inflate(R.layout.content_finalizar_instalacion,
                findViewById(R.id.contentFrame), true);
        setupBottomBar();

        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        if (referencia.isEmpty()) {
            referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido"));
        }

        txtFinalizarReferencia = content.findViewById(R.id.txtFinalizarReferencia);
        llFotosFaltantes = content.findViewById(R.id.llFotosFaltantes);
        editCobroMetalico = content.findViewById(R.id.editCobroMetalico);
        editCobroVisa = content.findViewById(R.id.editCobroVisa);
        rgExtras = content.findViewById(R.id.rgExtras);
        ratingSatisfaccion = content.findViewById(R.id.ratingSatisfaccion);
        editObservacionesFinales = content.findViewById(R.id.editObservacionesFinales);
        btnFinalizarAhora = content.findViewById(R.id.btnFinalizarAhora);
        btnFinalizarVolver = content.findViewById(R.id.btnFinalizarVolver);
        locationCaptureHelper = new EventLocationCaptureHelper(this);

        if (txtFinalizarReferencia != null) {
            if (!referencia.isEmpty()) {
                txtFinalizarReferencia.setText("Referencia " + referencia);
            } else {
                txtFinalizarReferencia.setText(UiText.placeholderSpan("Referencia no disponible"));
            }
        }

        if (btnFinalizarAhora != null) {
            btnFinalizarAhora.setOnClickListener(v -> finalizarInstalacion());
        }
        if (btnFinalizarVolver != null) {
            btnFinalizarVolver.setOnClickListener(v -> finish());
        }

        cargarFotosFaltantes();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (locationCaptureHelper != null) {
            locationCaptureHelper.stop();
        }
    }

    private void cargarFotosFaltantes() {
        if (referencia == null || referencia.trim().isEmpty())
            return;
        try {
            String url = PEDIDO_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&referencia=" + URLEncoder.encode(referencia.trim(), "UTF-8");

            RequestQueue queue = Volley.newRequestQueue(this);
            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> {
                        try {
                            JSONObject root = new JSONObject(response);
                            if (!root.optBoolean("success", false)) {
                                showMissingMessage("No se pudo cargar el pedido");
                                return;
                            }
                            JSONObject pedidoJson = root.optJSONObject("pedido");
                            if (pedidoJson == null) {
                                showMissingMessage("Pedido sin datos");
                                return;
                            }
                            JSONObject fotos = pedidoJson.optJSONObject("fotografias");
                            renderMissingPhotos(fotos);
                        } catch (JSONException e) {
                            showMissingMessage("Error al leer las fotos");
                        }
                    },
                    error -> showMissingMessage("Error de conexión al cargar las fotos"));
            queue.add(request);
        } catch (Exception e) {
            showMissingMessage("Error interno al cargar las fotos");
        }
    }

    private void renderMissingPhotos(JSONObject fotos) {
        if (llFotosFaltantes == null)
            return;
        llFotosFaltantes.removeAllViews();

        boolean missingAny = false;
        missingAny |= addMissingIfNeeded(fotos, "previas", "Faltan fotos previas a la instalación");
        missingAny |= addMissingIfNeeded(fotos, "acabada", "Faltan fotos instalación acabada");
        missingAny |= addMissingIfNeeded(fotos, "conforme", "Faltan fotos conforme cliente");

        if (!missingAny) {
            TextView ok = buildStatusRow("Fotografías completas", true);
            llFotosFaltantes.addView(ok);
        }
    }

    private boolean addMissingIfNeeded(JSONObject fotos, String key, String message) {
        JSONArray arr = fotos != null ? fotos.optJSONArray(key) : null;
        boolean missing = arr == null || arr.length() == 0;
        if (missing) {
            llFotosFaltantes.addView(buildStatusRow(message, false));
        }
        return missing;
    }

    private void showMissingMessage(String message) {
        if (llFotosFaltantes == null)
            return;
        llFotosFaltantes.removeAllViews();
        llFotosFaltantes.addView(buildStatusRow(message, false));
    }

    private TextView buildStatusRow(String text, boolean ok) {
        TextView tv = new TextView(this);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        params.bottomMargin = dp(8);
        tv.setLayoutParams(params);
        tv.setPadding(dp(12), dp(10), dp(12), dp(10));
        tv.setText(text);
        tv.setTextColor(0xFFFFFFFF);
        tv.setTextSize(13f);
        tv.setBackgroundResource(ok ? R.drawable.bg_alert_ok : R.drawable.bg_alert_missing);
        return tv;
    }

    private void finalizarInstalacion() {
        if (finalizando) {
            return;
        }
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombreUsuario = prefs.getString("nombre", "");
        if (nombreUsuario == null || nombreUsuario.trim().isEmpty()) {
            nombreUsuario = prefs.getString("usuario", "Instalador");
        }
        final String usuario = nombreUsuario;

        String cobroMetalico = getTextValue(editCobroMetalico, "0");
        String cobroVisa = getTextValue(editCobroVisa, "0");
        String extras = getSelectedExtras();
        String satisfaccion = ratingSatisfaccion != null
                ? String.valueOf((int) ratingSatisfaccion.getRating())
                : "";
        String observaciones = getTextValue(editObservacionesFinales, "");

        setFinalizandoState(true, "Obteniendo ubicación...");
        locationCaptureHelper.capture(new EventLocationCaptureHelper.Callback() {
            @Override
            public void onLocationReady(@androidx.annotation.NonNull EventLocationCaptureHelper.CapturedLocation location) {
                enviarFinalizacion(usuario, cobroMetalico, cobroVisa, extras, satisfaccion, observaciones, location);
            }

            @Override
            public void onLocationError(@androidx.annotation.NonNull String message) {
                setFinalizandoState(false, "Finalizar ahora");
                android.widget.Toast.makeText(FinalizarInstalacionActivity.this, message, android.widget.Toast.LENGTH_LONG).show();
            }
        });
    }

    private void enviarFinalizacion(
            String usuario,
            String cobroMetalico,
            String cobroVisa,
            String extras,
            String satisfaccion,
            String observaciones,
            EventLocationCaptureHelper.CapturedLocation location
    ) {
        setFinalizandoState(true, "Finalizando...");

        RequestQueue queue = Volley.newRequestQueue(this);
        StringRequest request = new StringRequest(
                Request.Method.POST,
                FINALIZAR_URL,
                response -> {
                    try {
                        JSONObject root = new JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            String msg = root.optString("message", "No se pudo finalizar");
                            android.widget.Toast.makeText(
                                    FinalizarInstalacionActivity.this,
                                    msg,
                                    android.widget.Toast.LENGTH_SHORT).show();
                            setFinalizandoState(false, "Finalizar ahora");
                            return;
                        }
                        String okMessage = root.optString("message", "Instalación finalizada");
                        android.widget.Toast.makeText(
                                FinalizarInstalacionActivity.this,
                                okMessage,
                                android.widget.Toast.LENGTH_SHORT).show();
                        setFinalizandoState(false, "Finalizar ahora");
                        finish();
                    } catch (JSONException e) {
                        setFinalizandoState(false, "Finalizar ahora");
                        android.widget.Toast.makeText(
                                FinalizarInstalacionActivity.this,
                                "Error al finalizar la instalación",
                                android.widget.Toast.LENGTH_SHORT).show();
                    }
                },
                error -> {
                    setFinalizandoState(false, "Finalizar ahora");
                    android.widget.Toast.makeText(
                            FinalizarInstalacionActivity.this,
                            "Error de conexión al finalizar",
                            android.widget.Toast.LENGTH_SHORT).show();
                }) {
            @Override
            protected Map<String, String> getParams() {
                Map<String, String> params = new HashMap<>();
                params.put("api_key", API_KEY);
                params.put("referencia", referencia);
                params.put("usuario", usuario);
                params.put("cobroMetalico", cobroMetalico);
                params.put("cobroVisa", cobroVisa);
                params.put("extras", extras);
                params.put("satisfaccion", satisfaccion);
                params.put("observaciones", observaciones);
                params.put("latitud", location.latitudeParam());
                params.put("longitud", location.longitudeParam());
                return params;
            }
        };

        queue.add(request);
    }

    private void setFinalizandoState(boolean loading, String buttonText) {
        finalizando = loading;
        if (btnFinalizarAhora != null) {
            btnFinalizarAhora.setEnabled(!loading);
            btnFinalizarAhora.setText(buttonText);
        }
        if (btnFinalizarVolver != null) {
            btnFinalizarVolver.setEnabled(!loading);
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String getTextValue(EditText editText, String fallback) {
        if (editText == null)
            return fallback;
        String value = editText.getText().toString().trim();
        return value.isEmpty() ? fallback : value.replace(",", ".");
    }

    private String getSelectedExtras() {
        if (rgExtras == null)
            return "";
        int checkedId = rgExtras.getCheckedRadioButtonId();
        if (checkedId == R.id.rbExtrasSi)
            return "si";
        if (checkedId == R.id.rbExtrasNo)
            return "no";
        return "";
    }
}
