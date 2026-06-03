package com.example.climamaniaapp;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Map;

public class InstallActivity extends BaseActivity {

    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String COMENTARIO_URL = "https://app.clminstal.es/api/add_comentario.php";
    private static final String FINALIZAR_URL = "https://app.clminstal.es/api/finalizar_instalacion.php";
    private static final String API_KEY = "TEST123";

    private String referencia;
    private String cliente;
    private Button btnFotosPrevias;
    private Button btnFotosIncidencias;
    private Button btnFotosAcabada;
    private Button btnFotosConforme;
    private Button btnFotosBOE;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_installation, contentFrame, true);

        setupBottomBar();

        TextView txtReferencia = content.findViewById(R.id.txtInstalacionReferencia);
        TextView txtCliente = content.findViewById(R.id.txtInstalacionCliente);
        EditText editComentarioPrivado = content.findViewById(R.id.editComentarioPrivado);
        Button btnGuardarComentarioPrivado = content.findViewById(R.id.btnGuardarComentarioPrivado);
        btnFotosPrevias = content.findViewById(R.id.btnFotosPrevias);
        btnFotosIncidencias = content.findViewById(R.id.btnFotosIncidencias);
        btnFotosAcabada = content.findViewById(R.id.btnFotosAcabada);
        btnFotosConforme = content.findViewById(R.id.btnFotosConforme);
        btnFotosBOE = content.findViewById(R.id.btnFotosBOE);
        Button btnAnadirComentarios = content.findViewById(R.id.btnAnadirComentarios);
        Button btnFinalizar = content.findViewById(R.id.btnFinalizarInstalacion);
        Button btnVolver = content.findViewById(R.id.btnInstalacionVolver);

        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        if (referencia.isEmpty()) {
            referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido"));
        }
        cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));

        if (referencia.isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        txtReferencia.setText("Referencia " + referencia);
        UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");

        // Comentarios privados (solo para este usuario, en este dispositivo)
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String usuario = prefs.getString("usuario", "anon");
        String pedidoKey = referencia.trim();
        String privateKey = "private_comment_" + usuario + "_" + pedidoKey;

        if (editComentarioPrivado != null) {
            String saved = prefs.getString(privateKey, "");
            if (saved != null && !saved.trim().isEmpty()) {
                editComentarioPrivado.setText(saved);
            }
        }
        if (btnGuardarComentarioPrivado != null && editComentarioPrivado != null) {
            btnGuardarComentarioPrivado.setOnClickListener(v -> {
                String texto = editComentarioPrivado.getText().toString().trim();
                prefs.edit().putString(privateKey, texto).apply();
                android.widget.Toast.makeText(
                        InstallActivity.this,
                        "Comentario privado guardado",
                        android.widget.Toast.LENGTH_SHORT
                ).show();
            });
        }

        if (btnFotosPrevias != null) {
            btnFotosPrevias.setOnClickListener(v -> abrirFotosPedido("previas", "Fotos previas", "PREINST"));
        }
        if (btnFotosIncidencias != null) {
            btnFotosIncidencias.setOnClickListener(v -> abrirFotosPedido("incidencias", "Fotos incidencias", "DURINST"));
        }
        if (btnFotosAcabada != null) {
            btnFotosAcabada.setOnClickListener(v -> abrirFotosPedido("acabada", "Fotos acabada", "POSTINST"));
        }
        if (btnFotosConforme != null) {
            btnFotosConforme.setOnClickListener(v -> abrirFotosPedido("conforme", "Fotos conforme", "CONFCLI"));
        }
        if (btnFotosBOE != null) {
            btnFotosBOE.setOnClickListener(v -> abrirFotosPedido("boe", "Documento BOE", "DOCUBOE"));
        }
        if (btnAnadirComentarios != null) {
            btnAnadirComentarios.setOnClickListener(v -> mostrarDialogoComentario(referencia));
        }
        if (btnFinalizar != null) {
            btnFinalizar.setOnClickListener(v -> abrirFinalizarInstalacion());
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        cargarEstadoFotos();
    }

    private void mostrarDialogoComentario(String referencia) {
        EditText input = new EditText(this);
        input.setHint("Escribe el comentario...");
        input.setMinLines(3);
        input.setMaxLines(6);
        input.setPadding(dp(12), dp(12), dp(12), dp(12));

        new AlertDialog.Builder(this)
                .setTitle("Añadir comentario")
                .setView(input)
                .setPositiveButton("Guardar", (dialog, which) -> {
                    String texto = input.getText().toString().trim();
                    if (texto.isEmpty()) {
                        android.widget.Toast.makeText(
                                InstallActivity.this,
                                "El comentario está vacío",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                        return;
                    }
                    enviarComentario(referencia, texto);
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void enviarComentario(String referencia, String texto) {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombreUsuario = prefs.getString("nombre", "");
        if (nombreUsuario == null || nombreUsuario.trim().isEmpty()) {
            nombreUsuario = prefs.getString("usuario", "Instalador");
        }
        final String usuario = nombreUsuario;

        RequestQueue queue = Volley.newRequestQueue(this);
        StringRequest request = new StringRequest(
                Request.Method.POST,
                COMENTARIO_URL,
                response -> {
                    try {
                        JSONObject root = new JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            String msg = root.optString("message", "No se pudo guardar");
                            android.widget.Toast.makeText(
                                    InstallActivity.this,
                                    msg,
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                            return;
                        }
                        android.widget.Toast.makeText(
                                InstallActivity.this,
                                "Comentario guardado",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    } catch (JSONException e) {
                        android.widget.Toast.makeText(
                                InstallActivity.this,
                                "Error al guardar el comentario",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    }
                },
                error -> android.widget.Toast.makeText(
                        InstallActivity.this,
                        "Error de conexión al guardar el comentario",
                        android.widget.Toast.LENGTH_SHORT
                ).show()
        ) {
            @Override
            protected Map<String, String> getParams() {
                Map<String, String> params = new HashMap<>();
                params.put("api_key", API_KEY);
                params.put("referencia", referencia);
                params.put("usuario", usuario);
                params.put("texto", texto);
                return params;
            }
        };

        queue.add(request);
    }

    private void abrirFinalizarInstalacion() {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Finalizar instalación")
                .setMessage("Vas a revisar y completar la información final. ¿Quieres continuar?")
                .setPositiveButton("Continuar", (dialog, which) -> {
                    android.content.Intent intent = new android.content.Intent(this, FinalizarInstalacionActivity.class);
                    intent.putExtra("referencia", referencia);
                    startActivity(intent);
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void finalizarInstalacion(String referencia) {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombreUsuario = prefs.getString("nombre", "");
        if (nombreUsuario == null || nombreUsuario.trim().isEmpty()) {
            nombreUsuario = prefs.getString("usuario", "Instalador");
        }
        final String usuario = nombreUsuario;

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
                                    InstallActivity.this,
                                    msg,
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                            return;
                        }
                        android.widget.Toast.makeText(
                                InstallActivity.this,
                                "Instalación finalizada",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    } catch (JSONException e) {
                        android.widget.Toast.makeText(
                                InstallActivity.this,
                                "Error al finalizar la instalación",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    }
                },
                error -> android.widget.Toast.makeText(
                        InstallActivity.this,
                        "Error de conexión al finalizar",
                        android.widget.Toast.LENGTH_SHORT
                ).show()
        ) {
            @Override
            protected Map<String, String> getParams() {
                Map<String, String> params = new HashMap<>();
                params.put("api_key", API_KEY);
                params.put("referencia", referencia);
                params.put("usuario", usuario);
                return params;
            }
        };

        queue.add(request);
    }

    private void abrirFotosPedido(String categoria, String titulo, String claveUpload) {
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
                                String msg = root.optString("message", "No se pudo cargar el pedido");
                                android.widget.Toast.makeText(
                                        InstallActivity.this,
                                        msg,
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                return;
                            }
                            JSONObject pedidoJson = root.optJSONObject("pedido");
                            if (pedidoJson == null) {
                                android.widget.Toast.makeText(
                                        InstallActivity.this,
                                        "Pedido sin datos",
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                return;
                            }
                            JSONObject fotos = pedidoJson.optJSONObject("fotografias");
                            JSONArray arr = fotos != null ? fotos.optJSONArray(categoria) : null;
                            android.content.Intent intent = new android.content.Intent(InstallActivity.this, PhotoListActivity.class);
                            intent.putExtra("titulo", titulo);
                            intent.putExtra("referencia", referencia);
                            intent.putExtra("categoria", categoria);
                            intent.putExtra("clave", claveUpload);
                            if (arr != null) {
                                intent.putExtra("fotos_json", arr.toString());
                            }
                            startActivity(intent);
                        } catch (JSONException e) {
                            android.widget.Toast.makeText(
                                    InstallActivity.this,
                                    "Error al leer las fotos",
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                        }
                    },
                    error -> android.widget.Toast.makeText(
                            InstallActivity.this,
                            "Error de conexión al cargar las fotos",
                            android.widget.Toast.LENGTH_SHORT
                    ).show()
            );

            queue.add(request);
        } catch (Exception e) {
            android.widget.Toast.makeText(
                    InstallActivity.this,
                    "Error interno al preparar la petición",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
        }
    }

    private void cargarEstadoFotos() {
        if (referencia == null || referencia.trim().isEmpty()) return;
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
                            if (!root.optBoolean("success", false)) return;
                            JSONObject pedidoJson = root.optJSONObject("pedido");
                            if (pedidoJson == null) return;
                            JSONObject fotos = pedidoJson.optJSONObject("fotografias");
                            actualizarBotonFoto(btnFotosPrevias, fotos, "previas");
                            actualizarBotonFoto(btnFotosIncidencias, fotos, "incidencias");
                            actualizarBotonFoto(btnFotosAcabada, fotos, "acabada");
                            actualizarBotonFoto(btnFotosConforme, fotos, "conforme");
                            actualizarBotonFoto(btnFotosBOE, fotos, "boe");
                        } catch (JSONException ignored) {
                        }
                    },
                    error -> {
                    }
            );
            queue.add(request);
        } catch (Exception ignored) {
        }
    }

    private void actualizarBotonFoto(Button button, JSONObject fotos, String key) {
        if (button == null) return;
        boolean hasFotos = false;
        if (fotos != null) {
            JSONArray arr = fotos.optJSONArray(key);
            hasFotos = arr != null && arr.length() > 0;
        }
        int color = androidx.core.content.ContextCompat.getColor(
                this,
                hasFotos ? android.R.color.holo_green_dark : R.color.colorPrimary
        );
        button.setBackgroundTintList(android.content.res.ColorStateList.valueOf(color));
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
