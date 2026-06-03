package com.example.climamaniaapp;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;

import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.material.button.MaterialButton;

import org.json.JSONObject;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public class CerrarGestionActivity extends BaseActivity {

    private static final String API_KEY = "TEST123";
    private static final String URL_CERRAR_VISITA =
            "https://app.clminstal.es/api/visita_cerrar.php";
    private static final String URL_CERRAR_INCIDENCIA =
            "https://app.clminstal.es/api/incidencia_cerrar.php";

    private TextView txtSaludo;
    private TextView txtRef;
    private TextView txtTitulo;
    private TextView txtCliente;
    private TextView txtDireccion;
    private TextView txtFinalizarTitulo;
    private TextView txtFinalizarInfo;
    private TextView txtFinalizarResumenLabel;
    private TextView txtCancelarTitulo;
    private TextView txtCancelarInfo;
    private EditText editFinalizarResumen;
    private EditText editMotivo;
    private MaterialButton btnFinalizar;
    private MaterialButton btnCancelar;
    private MaterialButton btnVolver;

    private RequestQueue requestQueue;

    private String tipoCaso = "";
    private String idCaso = "";
    private String cliente = "";
    private String direccion = "";
    private String poblacion = "";
    private String rol = "";
    private String usuario = "";
    private String equipo = "";
    private String autor = "";
    private boolean submitting = false;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_cerrar_gestion, contentFrame, true);

        setupBottomBar();
        requestQueue = Volley.newRequestQueue(this);

        txtSaludo = content.findViewById(R.id.txtCerrarGestionSaludo);
        txtRef = content.findViewById(R.id.txtCerrarGestionRef);
        txtTitulo = content.findViewById(R.id.txtCerrarGestionTitulo);
        txtCliente = content.findViewById(R.id.txtCerrarGestionCliente);
        txtDireccion = content.findViewById(R.id.txtCerrarGestionDireccion);
        txtFinalizarTitulo = content.findViewById(R.id.txtCerrarGestionFinalizarTitulo);
        txtFinalizarInfo = content.findViewById(R.id.txtCerrarGestionFinalizarInfo);
        txtFinalizarResumenLabel = content.findViewById(R.id.txtCerrarGestionFinalizarResumenLabel);
        txtCancelarTitulo = content.findViewById(R.id.txtCerrarGestionCancelarTitulo);
        txtCancelarInfo = content.findViewById(R.id.txtCerrarGestionCancelarInfo);
        editFinalizarResumen = content.findViewById(R.id.editCerrarGestionFinalizarResumen);
        editMotivo = content.findViewById(R.id.editCerrarGestionMotivo);
        btnFinalizar = content.findViewById(R.id.btnCerrarGestionFinalizar);
        btnCancelar = content.findViewById(R.id.btnCerrarGestionCancelar);
        btnVolver = content.findViewById(R.id.btnCerrarGestionVolver);

        if (editFinalizarResumen != null) {
            editFinalizarResumen.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        }
        if (editMotivo != null) {
            editMotivo.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        }

        bindUserContext();
        if (!bindIntentData()) {
            Toast.makeText(this, "No se pudo abrir el cierre de gestión", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        applyTextsByTipo();
        bindButtons();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (requestQueue != null) {
            requestQueue.cancelAll("cerrar_gestion");
        }
    }

    private void bindUserContext() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        String usuarioPref = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuarioPref.isEmpty()) {
            usuarioPref = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String displayName = !nombre.isEmpty() ? nombre : (!usuarioPref.isEmpty() ? usuarioPref : "instalador");
        if (txtSaludo != null) {
            txtSaludo.setText("Hola " + displayName);
        }
    }

    private boolean bindIntentData() {
        tipoCaso = UiText.sanitizeDbValue(getIntent().getStringExtra("tipo_caso")).toLowerCase();
        idCaso = UiText.sanitizeDbValue(getIntent().getStringExtra("id_caso"));
        cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));
        direccion = UiText.sanitizeDbValue(getIntent().getStringExtra("direccion"));
        poblacion = UiText.sanitizeDbValue(getIntent().getStringExtra("poblacion"));
        rol = UiText.sanitizeDbValue(getIntent().getStringExtra("rol"));
        usuario = UiText.sanitizeDbValue(getIntent().getStringExtra("usuario"));
        equipo = UiText.sanitizeDbValue(getIntent().getStringExtra("equipo"));
        autor = UiText.sanitizeDbValue(getIntent().getStringExtra("autor"));

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        if (rol.isEmpty()) {
            rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        }
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
            if (usuario.isEmpty()) {
                usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
            }
        }
        if (equipo.isEmpty()) {
            equipo = readEquipoFromPrefs(prefs);
        }
        if (autor.isEmpty()) {
            autor = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
            if (autor.isEmpty()) {
                autor = usuario;
            }
        }

        boolean tipoValido = "visita".equals(tipoCaso) || "incidencia".equals(tipoCaso);
        if (!tipoValido || idCaso.isEmpty()) {
            return false;
        }

        if (txtCliente != null) {
            txtCliente.setText(cliente.isEmpty() ? "Cliente no disponible" : cliente);
        }
        if (txtDireccion != null) {
            txtDireccion.setText(buildDireccion(direccion, poblacion));
        }
        return true;
    }

    private void applyTextsByTipo() {
        boolean isVisita = "visita".equals(tipoCaso);
        String nombreCaso = isVisita ? "visita" : "incidencia";
        String refLabel = (isVisita ? "Visita #" : "Incidencia #") + idCaso;

        if (txtRef != null) {
            txtRef.setText(refLabel);
        }
        if (txtTitulo != null) {
            txtTitulo.setText("Finalizar " + nombreCaso);
        }
        if (txtFinalizarTitulo != null) {
            txtFinalizarTitulo.setText("Finalizar " + nombreCaso);
        }
        if (txtFinalizarInfo != null) {
            txtFinalizarInfo.setText("La " + nombreCaso + " se marcará como resuelta.");
        }
        if (txtFinalizarResumenLabel != null) {
            txtFinalizarResumenLabel.setVisibility(isVisita ? View.GONE : View.VISIBLE);
        }
        if (editFinalizarResumen != null) {
            if (isVisita) {
                editFinalizarResumen.setVisibility(View.GONE);
            } else {
                editFinalizarResumen.setVisibility(View.VISIBLE);
                editFinalizarResumen.setHint("Describe brevemente cómo se ha resuelto la incidencia");
            }
        }
        if (txtCancelarTitulo != null) {
            txtCancelarTitulo.setText("Cancelar " + nombreCaso);
        }
        if (txtCancelarInfo != null) {
            txtCancelarInfo.setText("Es obligatorio indicar el motivo de la cancelación.");
        }
        if (editMotivo != null) {
            editMotivo.setHint("Ejemplo: El cliente no está interesado, no es viable...");
        }
        if (btnFinalizar != null) {
            btnFinalizar.setText("Finalizar " + nombreCaso);
        }
        if (btnCancelar != null) {
            btnCancelar.setText("Cancelar " + nombreCaso);
        }
    }

    private void bindButtons() {
        if (btnFinalizar != null) {
            btnFinalizar.setOnClickListener(v -> {
                String resumen = "";
                if ("incidencia".equals(tipoCaso) && editFinalizarResumen != null && editFinalizarResumen.getText() != null) {
                    resumen = UiText.sanitizeDbValue(editFinalizarResumen.getText().toString());
                    if (resumen.isEmpty()) {
                        editFinalizarResumen.setError("Debes indicar el resumen de la actuación");
                        editFinalizarResumen.requestFocus();
                        Toast.makeText(this, "Debes indicar el motivo/resumen de la actuación", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    editFinalizarResumen.setError(null);
                }
                sendCerrarRequest("finalizar", "", resumen);
            });
        }
        if (btnCancelar != null) {
            btnCancelar.setOnClickListener(v -> {
                String motivo = editMotivo != null && editMotivo.getText() != null
                        ? UiText.sanitizeDbValue(editMotivo.getText().toString())
                        : "";
                if (motivo.isEmpty()) {
                    if (editMotivo != null) {
                        editMotivo.setError("Debes indicar el motivo");
                        editMotivo.requestFocus();
                    }
                    Toast.makeText(this, "Debes indicar el motivo de cancelación", Toast.LENGTH_SHORT).show();
                    return;
                }
                if (editMotivo != null) {
                    editMotivo.setError(null);
                }
                sendCerrarRequest("cancelar", motivo, "");
            });
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
    }

    private void sendCerrarRequest(String accion, String motivo, String resumenActuacion) {
        if (submitting) {
            return;
        }

        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("rol", rol);
        params.put("usuario", usuario);
        params.put("equipo", equipo);
        params.put("autor", autor);
        params.put("accion", accion);

        boolean isVisita = "visita".equals(tipoCaso);
        if (isVisita) {
            params.put("id_visita", idCaso);
        } else {
            params.put("id_incidencia", idCaso);
        }
        if ("cancelar".equals(accion)) {
            params.put("motivo", motivo);
        } else if ("incidencia".equals(tipoCaso)) {
            params.put("resumen_actuacion", UiText.sanitizeDbValue(resumenActuacion));
        }

        String endpoint = isVisita ? URL_CERRAR_VISITA : URL_CERRAR_INCIDENCIA;
        setSubmitting(true);

        StringRequest request = new StringRequest(
                Request.Method.POST,
                endpoint,
                response -> {
                    try {
                        JSONObject root = new JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            setSubmitting(false);
                            Toast.makeText(this,
                                    getJsonMessage(root, "No se pudo actualizar"),
                                    Toast.LENGTH_LONG).show();
                            return;
                        }
                        Toast.makeText(this,
                                getJsonMessage(root, "Gestión actualizada correctamente"),
                                Toast.LENGTH_SHORT).show();
                        setResult(RESULT_OK);
                        finish();
                    } catch (Exception e) {
                        setSubmitting(false);
                        Toast.makeText(this, "Respuesta inválida del servidor", Toast.LENGTH_SHORT).show();
                    }
                },
                error -> {
                    setSubmitting(false);
                    Toast.makeText(this,
                            buildVolleyErrorMessage(error, "Error de conexión con el servidor"),
                            Toast.LENGTH_LONG).show();
                }) {
            @Override
            protected Map<String, String> getParams() {
                return params;
            }
        };

        request.setRetryPolicy(new DefaultRetryPolicy(20000, 1, 1.0f));
        request.setShouldCache(false);
        request.setTag("cerrar_gestion");
        requestQueue.add(request);
    }

    private void setSubmitting(boolean value) {
        submitting = value;
        if (btnFinalizar != null) {
            btnFinalizar.setEnabled(!value);
        }
        if (btnCancelar != null) {
            btnCancelar.setEnabled(!value);
        }
        if (btnVolver != null) {
            btnVolver.setEnabled(!value);
        }
    }

    private String getJsonMessage(JSONObject root, String fallback) {
        if (root == null) {
            return fallback;
        }
        String msg = UiText.sanitizeDbValue(root.optString("message", ""));
        return msg.isEmpty() ? fallback : msg;
    }

    private String buildVolleyErrorMessage(VolleyError error, String fallback) {
        if (error == null || error.networkResponse == null || error.networkResponse.data == null) {
            return fallback;
        }
        String body = new String(error.networkResponse.data, StandardCharsets.UTF_8).trim();
        return body.isEmpty() ? fallback : body;
    }

    private String buildDireccion(String dir, String pob) {
        String direccionClean = UiText.sanitizeDbValue(dir);
        String poblacionClean = UiText.sanitizeDbValue(pob);
        if (direccionClean.isEmpty() && poblacionClean.isEmpty()) {
            return "Dirección no disponible";
        }
        if (direccionClean.isEmpty()) {
            return poblacionClean;
        }
        if (poblacionClean.isEmpty()) {
            return direccionClean;
        }
        return direccionClean + ", " + poblacionClean;
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
}
