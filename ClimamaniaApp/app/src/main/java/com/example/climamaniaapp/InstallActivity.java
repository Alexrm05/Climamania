package com.example.climamaniaapp;

import android.app.Activity;
import android.content.SharedPreferences;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;

import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public class InstallActivity extends BaseActivity {

    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String COMENTARIO_URL = "https://app.clminstal.es/api/add_comentario.php";
    private static final String FINALIZAR_URL = "https://app.clminstal.es/api/finalizar_instalacion.php";
    private static final String[] GENERATE_BOE_URLS = new String[] {
            "https://app.clminstal.es/api/generar_boe_pdf.php"
    };
    private static final String[] SEND_DOCUMENTATION_URLS = new String[] {
            "https://app.clminstal.es/api/enviar_documentacion_instalacion.php"
    };
    private static final String API_KEY = "TEST123";

    private String referencia;
    private String cliente;
    private String pedidoJson;
    private Boolean requiereBoeSeleccionado;
    private boolean revisionBoeGuardada = false;
    private String observacionesConformidad = "";
    private String tipoFirmanteConformidad = "";
    private String firmanteNombreConformidad = "";
    private String firmanteApellidosConformidad = "";
    private String firmanteDniConformidad = "";
    private String firmaBase64Conformidad = "";
    private String pdfConformidad = "";
    private String pdfUrlConformidad = "";
    private String pdfBoe = "";
    private String pdfUrlBoe = "";
    private String submissionTokenConformidad = "";
    private boolean generandoBoe = false;
    private boolean enviandoDocumentacion = false;
    private Button btnFotosPrevias;
    private Button btnFotosIncidencias;
    private Button btnFotosAcabada;
    private Button btnFotosConforme;
    private Button btnFotosBOE;
    private final ActivityResultLauncher<Intent> conformeClienteLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    result -> {
                        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
                            return;
                        }
                        Intent data = result.getData();
                        referencia = UiText.sanitizeDbValue(data.getStringExtra("referencia"));
                        cliente = UiText.sanitizeDbValue(data.getStringExtra("cliente"));
                        pedidoJson = UiText.sanitizeDbValue(data.getStringExtra("pedido_json"));
                        if (data.hasExtra("requiere_boe")) {
                            requiereBoeSeleccionado = data.getBooleanExtra("requiere_boe", false);
                            if (requiereBoeSeleccionado) {
                                abrirRevisionBoe();
                            } else {
                                abrirConformidadCliente(false, false);
                            }
                        }
                    });
    private final ActivityResultLauncher<Intent> seriesBoeLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    result -> {
                        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
                            return;
                        }
                        Intent data = result.getData();
                        referencia = UiText.sanitizeDbValue(data.getStringExtra("referencia"));
                        cliente = UiText.sanitizeDbValue(data.getStringExtra("cliente"));
                        pedidoJson = UiText.sanitizeDbValue(data.getStringExtra("pedido_json"));
                        if (data.hasExtra("requiere_boe")) {
                            requiereBoeSeleccionado = data.getBooleanExtra("requiere_boe", false);
                        }
                        if (data.hasExtra("revision_boe_guardada")) {
                            revisionBoeGuardada = data.getBooleanExtra("revision_boe_guardada", false);
                            if (revisionBoeGuardada) {
                                abrirConformidadCliente(true, true);
                            }
                        }
                    });
    private final ActivityResultLauncher<Intent> conformidadLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    result -> {
                        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
                            return;
                        }
                        Intent data = result.getData();
                        referencia = UiText.sanitizeDbValue(data.getStringExtra("referencia"));
                        cliente = UiText.sanitizeDbValue(data.getStringExtra("cliente"));
                        pedidoJson = UiText.sanitizeDbValue(data.getStringExtra("pedido_json"));
                        requiereBoeSeleccionado = data.getBooleanExtra("requiere_boe", false);
                        revisionBoeGuardada = data.getBooleanExtra("revision_boe_guardada", false);
                        observacionesConformidad = UiText.sanitizeDbValue(data.getStringExtra("observaciones_conformidad"));
                        tipoFirmanteConformidad = UiText.sanitizeDbValue(data.getStringExtra("tipo_firmante"));
                        firmanteNombreConformidad = UiText.sanitizeDbValue(data.getStringExtra("firmante_nombre"));
                        firmanteApellidosConformidad = UiText.sanitizeDbValue(data.getStringExtra("firmante_apellidos"));
                        firmanteDniConformidad = UiText.sanitizeDbValue(data.getStringExtra("firmante_dni"));
                        firmaBase64Conformidad = UiText.sanitizeDbValue(data.getStringExtra("firma_base64_png"));
                        pdfConformidad = UiText.sanitizeDbValue(data.getStringExtra("pdf"));
                        pdfUrlConformidad = UiText.sanitizeDbValue(data.getStringExtra("pdf_url"));
                        submissionTokenConformidad = UiText.sanitizeDbValue(data.getStringExtra("submission_token"));
                        if (Boolean.TRUE.equals(requiereBoeSeleccionado) && revisionBoeGuardada) {
                            generarBoeSiAplica();
                        } else {
                            enviarDocumentacionSiAplica(false);
                        }
                    });

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
        Button btnFirmaConformeCliente = content.findViewById(R.id.btnFirmaConformeCliente);
        Button btnFinalizar = content.findViewById(R.id.btnFinalizarInstalacion);
        Button btnVolver = content.findViewById(R.id.btnInstalacionVolver);

        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        if (referencia.isEmpty()) {
            referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido"));
        }
        cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));
        pedidoJson = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido_json"));

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
        if (btnFirmaConformeCliente != null) {
            btnFirmaConformeCliente.setOnClickListener(v -> abrirDecisionConformeCliente());
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

    private void abrirDecisionConformeCliente() {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, ConformeClienteBoeDecisionActivity.class);
        intent.putExtra("referencia", referencia);
        if (cliente != null && !cliente.trim().isEmpty()) {
            intent.putExtra("cliente", cliente);
        }
        if (pedidoJson != null && !pedidoJson.trim().isEmpty()) {
            intent.putExtra("pedido_json", pedidoJson);
        }
        if (requiereBoeSeleccionado != null) {
            intent.putExtra("requiere_boe_preseleccionado", requiereBoeSeleccionado);
        }
        conformeClienteLauncher.launch(intent);
    }

    private void abrirRevisionBoe() {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, ConformeClienteSeriesBoeActivity.class);
        intent.putExtra("referencia", referencia);
        if (cliente != null && !cliente.trim().isEmpty()) {
            intent.putExtra("cliente", cliente);
        }
        if (pedidoJson != null && !pedidoJson.trim().isEmpty()) {
            intent.putExtra("pedido_json", pedidoJson);
        }
        intent.putExtra("requiere_boe", true);
        seriesBoeLauncher.launch(intent);
    }

    private void abrirConformidadCliente(boolean requiereBoe, boolean revisionGuardada) {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, ConformeClienteConformidadActivity.class);
        intent.putExtra("referencia", referencia);
        if (cliente != null && !cliente.trim().isEmpty()) {
            intent.putExtra("cliente", cliente);
        }
        if (pedidoJson != null && !pedidoJson.trim().isEmpty()) {
            intent.putExtra("pedido_json", pedidoJson);
        }
        intent.putExtra("requiere_boe", requiereBoe);
        intent.putExtra("revision_boe_guardada", revisionGuardada);
        conformidadLauncher.launch(intent);
    }

    private void generarBoeSiAplica() {
        if (generandoBoe) {
            return;
        }
        if (!Boolean.TRUE.equals(requiereBoeSeleccionado) || !revisionBoeGuardada) {
            return;
        }
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        if (submissionTokenConformidad == null || submissionTokenConformidad.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "No se pudo relacionar el PDF BOE con la conformidad", android.widget.Toast.LENGTH_LONG).show();
            return;
        }
        if (firmaBase64Conformidad == null || firmaBase64Conformidad.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "No se pudo recuperar la firma para el BOE", android.widget.Toast.LENGTH_LONG).show();
            return;
        }

        generandoBoe = true;
        android.widget.Toast.makeText(this, "Generando PDF BOE...", android.widget.Toast.LENGTH_SHORT).show();
        generarBoeWithFallback(0, "", buildBoePayload());
    }

    private Map<String, String> buildBoePayload() {
        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("referencia", UiText.sanitizeDbValue(referencia));
        params.put("submission_token", UiText.sanitizeDbValue(submissionTokenConformidad));
        params.put("tipo_firmante", UiText.sanitizeDbValue(tipoFirmanteConformidad));
        params.put("firmante_nombre", UiText.sanitizeDbValue(firmanteNombreConformidad));
        params.put("firmante_apellidos", UiText.sanitizeDbValue(firmanteApellidosConformidad));
        params.put("firmante_dni", UiText.sanitizeDbValue(firmanteDniConformidad));
        params.put("firma_base64_png", UiText.sanitizeDbValue(firmaBase64Conformidad));
        params.put("usuario", resolveUsuarioActual());
        return params;
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

    private void generarBoeWithFallback(int index, String lastError, Map<String, String> payload) {
        if (index >= GENERATE_BOE_URLS.length) {
            generandoBoe = false;
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo generar el PDF BOE";
            }
            showLongMessageDialog(
                    "Error al generar el BOE",
                    "PDF de conformidad generado.\n\n" + msg
            );
            cargarEstadoFotos();
            return;
        }

        RequestQueue queue = Volley.newRequestQueue(this);
        StringRequest request = new StringRequest(
                Request.Method.POST,
                GENERATE_BOE_URLS[index],
                response -> {
                    String parseError = handleGenerateBoeResponse(response);
                    if (parseError != null) {
                        generarBoeWithFallback(index + 1, parseError, payload);
                    }
                },
                error -> generarBoeWithFallback(index + 1, buildVolleyErrorMessage(error, "No se pudo generar el PDF BOE"), payload)
        ) {
            @Override
            protected Map<String, String> getParams() {
                return payload;
            }
        };
        request.setShouldCache(false);
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        queue.add(request);
    }

    @Nullable
    private String handleGenerateBoeResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                return UiText.sanitizeDbValue(root.optString("message", "No se pudo generar el PDF BOE"));
            }
            pdfBoe = UiText.sanitizeDbValue(root.optString("pdf", ""));
            pdfUrlBoe = UiText.sanitizeDbValue(root.optString("pdf_url", ""));
            generandoBoe = false;
            enviarDocumentacionSiAplica(true);
            return null;
        } catch (Exception e) {
            generandoBoe = false;
            return "Respuesta inválida del servidor";
        }
    }

    private String buildVolleyErrorMessage(VolleyError error, String fallback) {
        if (error == null) {
            return fallback;
        }
        if (error.networkResponse != null && error.networkResponse.data != null) {
            String body = new String(error.networkResponse.data, StandardCharsets.UTF_8).trim();
            if (!body.isEmpty()) {
                return sanitizeServerErrorMessage(body, fallback);
            }
            return "Error HTTP " + error.networkResponse.statusCode;
        }
        String msg = error.getMessage();
        if (msg != null && !msg.trim().isEmpty()) {
            return sanitizeServerErrorMessage(msg.trim(), fallback);
        }
        return fallback;
    }

    private String sanitizeServerErrorMessage(String raw, String fallback) {
        String clean = UiText.sanitizeDbValue(raw);
        if (clean.isEmpty()) {
            return fallback;
        }

        String lower = clean.toLowerCase();
        if (lower.contains("<!doctype") || lower.contains("<html") || lower.contains("<body")) {
            return fallback + ". El servidor devolvió una página HTML en lugar de una respuesta válida";
        }

        clean = clean.replaceAll("(?is)<script.*?>.*?</script>", " ");
        clean = clean.replaceAll("(?is)<style.*?>.*?</style>", " ");
        clean = clean.replaceAll("(?is)<[^>]+>", " ");
        clean = clean.replaceAll("\\s+", " ").trim();
        if (clean.isEmpty()) {
            return fallback;
        }
        return clean;
    }

    private void showLongMessageDialog(String title, String message) {
        TextView textView = new TextView(this);
        textView.setText(UiText.sanitizeDbValue(message));
        int padding = dp(20);
        textView.setPadding(padding, padding, padding, padding / 2);
        textView.setTextSize(16f);

        ScrollView scrollView = new ScrollView(this);
        scrollView.addView(textView);

        new AlertDialog.Builder(this)
                .setTitle(title)
                .setView(scrollView)
                .setPositiveButton("Cerrar", null)
                .show();
    }

    private void enviarDocumentacionSiAplica(boolean requiereBoe) {
        if (enviandoDocumentacion) {
            return;
        }
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        if (submissionTokenConformidad == null || submissionTokenConformidad.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "No se pudo localizar la documentación para enviar", android.widget.Toast.LENGTH_LONG).show();
            cargarEstadoFotos();
            return;
        }
        if (pdfConformidad == null || pdfConformidad.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Falta el documento de conformidad firmado", android.widget.Toast.LENGTH_LONG).show();
            cargarEstadoFotos();
            return;
        }
        if (requiereBoe && (pdfBoe == null || pdfBoe.trim().isEmpty())) {
            android.widget.Toast.makeText(this, "Falta el documento BOE obligatorio para esta instalación", android.widget.Toast.LENGTH_LONG).show();
            cargarEstadoFotos();
            return;
        }

        enviandoDocumentacion = true;
        android.widget.Toast.makeText(this, "Enviando documentación...", android.widget.Toast.LENGTH_SHORT).show();
        enviarDocumentacionWithFallback(0, "", buildSendDocumentationPayload(requiereBoe));
    }

    private Map<String, String> buildSendDocumentationPayload(boolean requiereBoe) {
        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("referencia", UiText.sanitizeDbValue(referencia));
        params.put("submission_token", UiText.sanitizeDbValue(submissionTokenConformidad));
        params.put("requiere_boe", String.valueOf(requiereBoe));
        return params;
    }

    private void enviarDocumentacionWithFallback(int index, String lastError, Map<String, String> payload) {
        if (index >= SEND_DOCUMENTATION_URLS.length) {
            enviandoDocumentacion = false;
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo enviar la documentación";
            }
            android.widget.Toast.makeText(this, msg, android.widget.Toast.LENGTH_LONG).show();
            cargarEstadoFotos();
            return;
        }

        RequestQueue queue = Volley.newRequestQueue(this);
        StringRequest request = new StringRequest(
                Request.Method.POST,
                SEND_DOCUMENTATION_URLS[index],
                response -> {
                    String parseError = handleSendDocumentationResponse(response);
                    if (parseError != null) {
                        enviarDocumentacionWithFallback(index + 1, parseError, payload);
                    }
                },
                error -> enviarDocumentacionWithFallback(
                        index + 1,
                        buildVolleyErrorMessage(error, "No se pudo enviar la documentación"),
                        payload
                )
        ) {
            @Override
            protected Map<String, String> getParams() {
                return payload;
            }
        };
        request.setShouldCache(false);
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        queue.add(request);
    }

    @Nullable
    private String handleSendDocumentationResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                return UiText.sanitizeDbValue(root.optString("message", "No se pudo enviar la documentación"));
            }
            enviandoDocumentacion = false;
            String destinatarioCliente = UiText.sanitizeDbValue(root.optString("destinatario_cliente", ""));
            String toastMessage = destinatarioCliente.isEmpty()
                    ? UiText.sanitizeDbValue(root.optString("message", "Documentación enviada"))
                    : "Documentación enviada a " + destinatarioCliente;
            android.widget.Toast.makeText(
                    this,
                    toastMessage,
                    android.widget.Toast.LENGTH_LONG
            ).show();
            cargarEstadoFotos();
            return null;
        } catch (Exception e) {
            enviandoDocumentacion = false;
            return "Respuesta inválida del servidor";
        }
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
