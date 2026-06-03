package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ScrollView;
import android.widget.TextView;

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
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class EventDetailActivity extends BaseActivity {

    // URL base de la gestión de instalaciones en la web
    // Ajusta esta constante si tu ruta es distinta.
    private static final String INSTALL_WEB_BASE =
            "https://app.clminstal.es/gestion_instalacion.php?ref=";
    private static final String PEDIDO_URL =
            "https://app.clminstal.es/api/get_pedido.php";
    private static final String COMENTARIO_URL =
            "https://app.clminstal.es/api/add_comentario.php";
    private static final String FINALIZAR_URL =
            "https://app.clminstal.es/api/finalizar_instalacion.php";
    private static final String API_KEY = "TEST123";

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_event_detail, contentFrame, true);

        setupBottomBar();

        TextView txtSaludo       = content.findViewById(R.id.txtDetalleSaludo);
        TextView txtRefLinea     = content.findViewById(R.id.txtDetalleReferencia);
        TextView txtPedido       = content.findViewById(R.id.txtDetallePedido);
        TextView txtCliente      = content.findViewById(R.id.txtDetalleCliente);
        TextView txtHoraDet      = content.findViewById(R.id.txtDetalleHora);
        TextView txtEquipoDet    = content.findViewById(R.id.txtDetalleEquipo);
        TextView txtEstadoDet    = content.findViewById(R.id.txtDetalleEstado);
        TextView txtWhatsappDet  = content.findViewById(R.id.txtDetalleWhatsapp);
        TextView txtDireccionDet = content.findViewById(R.id.txtDetalleDireccion);
        TextView txtDetallesDet  = content.findViewById(R.id.txtDetalleDetalles);
        TextView txtComentariosDet = content.findViewById(R.id.txtDetalleComentarios);
        TextView txtTelefonoDet  = content.findViewById(R.id.txtDetalleTelefono);
        View colorStrip          = content.findViewById(R.id.colorStripDetail);
        Button btnBack           = content.findViewById(R.id.btnBack);
        EditText editComentarioPrivado = content.findViewById(R.id.editComentarioPrivado);
        Button btnGuardarComentarioPrivado = content.findViewById(R.id.btnGuardarComentarioPrivado);
        Button btnVerDatos       = content.findViewById(R.id.btnVerDatosInstalacion);
        Button btnFotosCliente   = content.findViewById(R.id.btnFotosCliente);
        Button btnFotosPrevias   = content.findViewById(R.id.btnFotosPrevias);
        Button btnFotosIncid     = content.findViewById(R.id.btnFotosIncidencias);
        Button btnFotosAcabada   = content.findViewById(R.id.btnFotosAcabada);
        Button btnFotosConforme  = content.findViewById(R.id.btnFotosConforme);
        Button btnFotosBOE       = content.findViewById(R.id.btnFotosBOE);
        Button btnAddComentarios = content.findViewById(R.id.btnAnadirComentarios);
        Button btnFinalizar      = content.findViewById(R.id.btnFinalizarInstalacion);
        Button btnConsultarOtra  = content.findViewById(R.id.btnConsultarOtra);
        Button btnIrCalendario   = content.findViewById(R.id.btnIrCalendario);

        Intent intent = getIntent();
        String pedido    = UiText.sanitizeDbValue(intent.getStringExtra("pedido"));
        String cliente   = UiText.sanitizeDbValue(intent.getStringExtra("cliente"));
        String hora      = UiText.sanitizeDbValue(intent.getStringExtra("hora"));
        String equipo    = UiText.sanitizeDbValue(intent.getStringExtra("equipoCodigo"));
        String estado    = UiText.sanitizeDbValue(intent.getStringExtra("estado"));
        String direccion = UiText.sanitizeDbValue(intent.getStringExtra("direccion"));
        String telefono    = UiText.sanitizeDbValue(intent.getStringExtra("telefono"));
        String whatsapp    = UiText.sanitizeDbValue(intent.getStringExtra("whatsapp"));
        String detalles    = UiText.sanitizeDbValue(intent.getStringExtra("detalles"));
        String comentarios = UiText.sanitizeDbValue(intent.getStringExtra("comentarios"));
        String concertada  = UiText.sanitizeDbValue(intent.getStringExtra("concertada"));
        String emailEquipo = UiText.sanitizeDbValue(intent.getStringExtra("emailEquipo"));
        String colorHex    = UiText.sanitizeDbValue(intent.getStringExtra("colorHex"));

        // Comentarios privados (solo para este usuario, en este dispositivo)
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String usuario = prefs.getString("usuario", "anon");
        String pedidoKey = pedido.isEmpty() ? "sin_pedido" : pedido.trim();
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
                        EventDetailActivity.this,
                        "Comentario privado guardado",
                        android.widget.Toast.LENGTH_SHORT
                ).show();
            });
        }

        // Saludo + referencia
        if (txtSaludo != null) {
            if (!cliente.isEmpty()) {
                txtSaludo.setText("Hola " + cliente);
            } else {
                txtSaludo.setText(UiText.placeholderSpan("Cliente no disponible"));
            }
        }
        if (txtRefLinea != null) {
            if (!pedido.isEmpty()) {
                txtRefLinea.setText("Referencia " + pedido);
            } else {
                txtRefLinea.setText(UiText.placeholderSpan("Referencia no disponible"));
            }
        }
        UiText.setTextOrPlaceholder(txtHoraDet, hora, "Horario no disponible");
        UiText.setTextOrPlaceholder(txtPedido, pedido, "Pedido no disponible");
        UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");
        UiText.setLabelOrPlaceholder(txtEquipoDet, "Equipo", equipo, "Equipo no asignado");

        // Regla: si el texto de estado contiene "finalizado" => finalizado; en caso contrario => sin finalizar
        if (!estado.isEmpty()) {
            boolean esFinalizado = estado.toLowerCase(java.util.Locale.ROOT).contains("finalizado");
            StringBuilder estadoLinea = new StringBuilder();
            estadoLinea.append("Estado: ").append(esFinalizado ? "Finalizado" : "Sin finalizar");
            if (!concertada.isEmpty()) {
                estadoLinea.append(" · Concertada: ").append(concertada);
            }
            txtEstadoDet.setText(estadoLinea.toString());
            styleEstadoChip(txtEstadoDet, esFinalizado);
        } else {
            txtEstadoDet.setText(UiText.placeholderSpan("Estado no disponible"));
        }

        UiText.setLabelOrPlaceholder(txtWhatsappDet, "WhatsApp", whatsapp, "WhatsApp no disponible");
        UiText.setTextOrPlaceholder(txtDireccionDet, direccion, "Dirección no disponible");
        UiText.setLabelOrPlaceholder(txtTelefonoDet, "Teléfono", telefono, "Teléfono no disponible");

        // Detalles técnicos
        if (!detalles.isEmpty()) {
            txtDetallesDet.setText("Detalles:\n" + detalles);
        } else {
            txtDetallesDet.setText(UiText.placeholderSpan("Detalles no disponibles"));
        }

        // Comentarios internos + email del equipo si existe
        StringBuilder comentariosLinea = new StringBuilder();
        if (!comentarios.isEmpty()) {
            comentariosLinea.append("Comentarios:\n").append(comentarios);
        }
        if (!emailEquipo.isEmpty()) {
            if (comentariosLinea.length() > 0) comentariosLinea.append("\n\n");
            comentariosLinea.append("Contacto equipo: ").append(emailEquipo);
        }
        if (comentariosLinea.length() > 0) {
            txtComentariosDet.setText(comentariosLinea.toString());
        } else {
            txtComentariosDet.setText(UiText.placeholderSpan("Comentarios no disponibles"));
        }

        String title;
        if (pedido != null && !pedido.trim().isEmpty() &&
                cliente != null && !cliente.trim().isEmpty()) {
            title = pedido.trim() + " · " + cliente.trim();
        } else if (pedido != null && !pedido.trim().isEmpty()) {
            title = pedido.trim();
        } else if (cliente != null && !cliente.trim().isEmpty()) {
            title = cliente.trim();
        } else {
            title = getString(R.string.app_name);
        }

        setTitle(title);

        // Aplicar color del evento a la banda superior y al título, si viene informado
        int accentColor = ContextCompat.getColor(this, R.color.colorPrimaryDark);
        if (colorHex != null && !colorHex.trim().isEmpty()) {
            String hex = colorHex.trim();
            if (!hex.startsWith("#")) hex = "#" + hex;
            try {
                accentColor = Color.parseColor(hex);
            } catch (IllegalArgumentException ignored) {
                // usamos el color por defecto
            }
        }
        colorStrip.setBackgroundColor(accentColor);
        txtPedido.setTextColor(accentColor);

        btnBack.setOnClickListener(v -> finish());

        // De momento, las acciones muestran un mensaje informativo.
        View.OnClickListener notImplemented = v ->
                android.widget.Toast.makeText(
                        EventDetailActivity.this,
                        "Funcionalidad disponible en la versión web.",
                        android.widget.Toast.LENGTH_SHORT
                ).show();

        // Acciones que abren la gestión web de la referencia actual
        View.OnClickListener openGestionWeb = v -> {
            if (pedido == null || pedido.trim().isEmpty()) {
                android.widget.Toast.makeText(
                        EventDetailActivity.this,
                        "Referencia no disponible para esta instalación.",
                        android.widget.Toast.LENGTH_SHORT
                ).show();
                return;
            }
            String url = INSTALL_WEB_BASE + pedido.trim();
            Intent webIntent = new Intent(EventDetailActivity.this, WebViewActivity.class);
            webIntent.putExtra("target_url", url);
            startActivity(webIntent);
        };

        // Acciones de fotos (carga desde API)
        View.OnClickListener fotosCliente = v -> abrirFotosPedido(pedido, "cliente", "Fotos del cliente", "FOTOCLI");
        View.OnClickListener fotosPrevias = v -> abrirFotosPedido(pedido, "previas", "Fotos previas", "PREINST");
        View.OnClickListener fotosIncid = v -> abrirFotosPedido(pedido, "incidencias", "Fotos incidencias", "DURINST");
        View.OnClickListener fotosAcabada = v -> abrirFotosPedido(pedido, "acabada", "Fotos acabada", "POSTINST");
        View.OnClickListener fotosConforme = v -> abrirFotosPedido(pedido, "conforme", "Fotos conforme", "CONFCLI");
        View.OnClickListener fotosBoe = v -> abrirFotosPedido(pedido, "boe", "Documento BOE", "DOCUBOE");

        if (btnVerDatos != null) {
            btnVerDatos.setOnClickListener(v -> cargarDetallePedido(pedido));
        }
        if (btnFotosCliente != null)  btnFotosCliente.setOnClickListener(fotosCliente);
        if (btnFotosPrevias != null)  btnFotosPrevias.setOnClickListener(fotosPrevias);
        if (btnFotosIncid != null)    btnFotosIncid.setOnClickListener(fotosIncid);
        if (btnFotosAcabada != null)  btnFotosAcabada.setOnClickListener(fotosAcabada);
        if (btnFotosConforme != null) btnFotosConforme.setOnClickListener(fotosConforme);
        if (btnFotosBOE != null)      btnFotosBOE.setOnClickListener(fotosBoe);
        if (btnAddComentarios != null)btnAddComentarios.setOnClickListener(v ->
                mostrarDialogoComentario(pedido, txtComentariosDet));
        if (btnFinalizar != null)     btnFinalizar.setOnClickListener(v ->
                mostrarDialogoFinalizar(pedido, txtEstadoDet));

        if (btnConsultarOtra != null) {
            btnConsultarOtra.setOnClickListener(v -> finish());
        }
        if (btnIrCalendario != null) {
            btnIrCalendario.setOnClickListener(v -> {
                Intent i = new Intent(EventDetailActivity.this, CalendarActivity.class);
                startActivity(i);
                finish();
            });
        }
    }

    private void styleEstadoChip(TextView view, boolean finalizado) {
        int bgColor = finalizado ? Color.parseColor("#2E7D32") : Color.parseColor("#F57C00");
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(bgColor);
        bg.setCornerRadius(dp(14));
        view.setBackground(bg);
        view.setTextColor(Color.WHITE);
        view.setTypeface(null, Typeface.BOLD);
        view.setPadding(dp(10), dp(4), dp(10), dp(4));
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void cargarDetallePedido(String referencia) {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(
                    EventDetailActivity.this,
                    "Referencia no disponible",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
            return;
        }

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
                                        EventDetailActivity.this,
                                        msg,
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                return;
                            }
                            JSONObject pedidoJson = root.optJSONObject("pedido");
                            if (pedidoJson == null) {
                                android.widget.Toast.makeText(
                                        EventDetailActivity.this,
                                        "Pedido sin datos",
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                return;
                            }
                            Intent intent = new Intent(EventDetailActivity.this, PedidoDetailActivity.class);
                            intent.putExtra("pedido_json", pedidoJson.toString());
                            startActivity(intent);
                        } catch (JSONException e) {
                            android.widget.Toast.makeText(
                                    EventDetailActivity.this,
                                    "Error al leer el pedido",
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                        }
                    },
                    error -> android.widget.Toast.makeText(
                            EventDetailActivity.this,
                            "Error de conexión al cargar el pedido",
                            android.widget.Toast.LENGTH_SHORT
                    ).show()
            );

            queue.add(request);
        } catch (Exception e) {
            android.widget.Toast.makeText(
                    EventDetailActivity.this,
                    "Error interno al preparar la petición",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
        }
    }

    private void mostrarDialogoComentario(String referencia, TextView txtComentariosDet) {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(
                    EventDetailActivity.this,
                    "Referencia no disponible",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
            return;
        }

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
                                EventDetailActivity.this,
                                "El comentario está vacío",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                        return;
                    }
                    enviarComentario(referencia, texto, txtComentariosDet);
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void enviarComentario(String referencia, String texto, TextView txtComentariosDet) {
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
                                    EventDetailActivity.this,
                                    msg,
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                            return;
                        }

                        String existente = txtComentariosDet != null
                                ? txtComentariosDet.getText().toString().trim()
                                : "";
                        String nuevo = "Comentario (" + usuario + "): " + texto;
                        String resultado = existente.isEmpty()
                                ? nuevo
                                : existente + "\n\n" + nuevo;

                        if (txtComentariosDet != null) {
                            txtComentariosDet.setText(resultado);
                            txtComentariosDet.setVisibility(View.VISIBLE);
                        }

                        android.widget.Toast.makeText(
                                EventDetailActivity.this,
                                "Comentario guardado",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    } catch (JSONException e) {
                        android.widget.Toast.makeText(
                                EventDetailActivity.this,
                                "Error al guardar el comentario",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    }
                },
                error -> android.widget.Toast.makeText(
                        EventDetailActivity.this,
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

    private void mostrarDialogoFinalizar(String referencia, TextView txtEstadoDet) {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(
                    EventDetailActivity.this,
                    "Referencia no disponible",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
            return;
        }

        new AlertDialog.Builder(this)
                .setTitle("Finalizar instalación")
                .setMessage("Esta acción marcará la instalación como finalizada.")
                .setPositiveButton("Finalizar", (dialog, which) ->
                        finalizarInstalacion(referencia, txtEstadoDet))
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void finalizarInstalacion(String referencia, TextView txtEstadoDet) {
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
                                    EventDetailActivity.this,
                                    msg,
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                            return;
                        }

                        if (txtEstadoDet != null) {
                            txtEstadoDet.setText("Estado: Finalizado");
                            styleEstadoChip(txtEstadoDet, true);
                            txtEstadoDet.setVisibility(View.VISIBLE);
                        }

                        android.widget.Toast.makeText(
                                EventDetailActivity.this,
                                "Instalación finalizada",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    } catch (JSONException e) {
                        android.widget.Toast.makeText(
                                EventDetailActivity.this,
                                "Error al finalizar la instalación",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    }
                },
                error -> android.widget.Toast.makeText(
                        EventDetailActivity.this,
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

    private void abrirFotosPedido(String referencia, String categoria, String titulo, String claveUpload) {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(
                    EventDetailActivity.this,
                    "Referencia no disponible",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
            return;
        }

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
                                        EventDetailActivity.this,
                                        msg,
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                return;
                            }
                            JSONObject pedidoJson = root.optJSONObject("pedido");
                            if (pedidoJson == null) {
                                android.widget.Toast.makeText(
                                        EventDetailActivity.this,
                                        "Pedido sin datos",
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                return;
                            }
                            JSONObject fotos = pedidoJson.optJSONObject("fotografias");
                            JSONArray arr = fotos != null ? fotos.optJSONArray(categoria) : null;
                            Intent intent = new Intent(EventDetailActivity.this, PhotoListActivity.class);
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
                                    EventDetailActivity.this,
                                    "Error al leer las fotos",
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                        }
                    },
                    error -> android.widget.Toast.makeText(
                            EventDetailActivity.this,
                            "Error de conexión al cargar las fotos",
                            android.widget.Toast.LENGTH_SHORT
                    ).show()
            );

            queue.add(request);
        } catch (Exception e) {
            android.widget.Toast.makeText(
                    EventDetailActivity.this,
                    "Error interno al preparar la petición",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
        }
    }

    private void mostrarDialogoPedido(String texto) {
        TextView tv = new TextView(this);
        tv.setText(texto);
        tv.setTextSize(13f);
        tv.setTextColor(Color.parseColor("#212121"));
        tv.setPadding(dp(16), dp(16), dp(16), dp(16));

        ScrollView scroll = new ScrollView(this);
        scroll.addView(tv);

        new AlertDialog.Builder(this)
                .setTitle("Detalle del pedido")
                .setView(scroll)
                .setPositiveButton("Cerrar", null)
                .show();
    }

    private String buildPedidoTexto(JSONObject pedido) {
        StringBuilder sb = new StringBuilder();

        String cliente = UiText.sanitizeDbValue(pedido.optString("cliente", ""));
        String referencia = UiText.sanitizeDbValue(pedido.optString("referencia", ""));
        sb.append("Hola ").append(cliente.isEmpty() ? "Instalador" : cliente).append("\n\n");
        sb.append("REFERENCIA: ")
                .append(referencia.isEmpty() ? "No disponible" : referencia)
                .append("\n\n");

        sb.append("EQUIPO INSTALADORES ASIGNADOS\n\n");
        JSONArray equipos = pedido.optJSONArray("equipo_asignado");
        if (equipos != null && equipos.length() > 0) {
            for (int i = 0; i < equipos.length(); i++) {
                JSONObject eq = equipos.optJSONObject(i);
                if (eq == null) continue;
                String desc = UiText.sanitizeDbValue(eq.optString("descripcion", ""));
                String fecha = formatFecha(eq.optString("start", ""));
                sb.append(desc.isEmpty() ? "Equipo sin descripción" : desc)
                        .append(" el dia ")
                        .append(fecha.isEmpty() ? "-" : fecha)
                        .append("\n");
            }
        } else {
            sb.append("Sin equipo asignado\n");
        }
        JSONArray finalizadas = pedido.optJSONArray("finalizaciones");
        if (finalizadas != null && finalizadas.length() > 0) {
            for (int i = 0; i < finalizadas.length(); i++) {
                JSONObject fin = finalizadas.optJSONObject(i);
                if (fin == null) continue;
                String usuario = UiText.sanitizeDbValue(fin.optString("Usuario", ""));
                String fecha = formatFecha(fin.optString("Fecha", ""));
                sb.append("Instalación Finalizada por ")
                        .append(usuario.isEmpty() ? "-" : usuario)
                        .append(" el dia ")
                        .append(fecha.isEmpty() ? "-" : fecha)
                        .append("\n");
            }
        }

        sb.append("\nARTICULOS AL INSTALAR Y OBSERVACIONES AL AGENDAR LA INSTALACION\n\n");
        JSONObject agenda = pedido.optJSONObject("articulos_agenda");
        String detalles = agenda != null ? UiText.sanitizeDbValue(agenda.optString("detalles", "")) : "";
        String comentarios = agenda != null ? UiText.sanitizeDbValue(agenda.optString("comentarios", "")) : "";
        if (!detalles.isEmpty() || !comentarios.isEmpty()) {
            sb.append(detalles);
            if (!detalles.isEmpty() && !comentarios.isEmpty()) sb.append(": ");
            sb.append(comentarios).append("\n");
        } else {
            sb.append("No disponible\n");
        }

        sb.append("\nDIRECCION DE LA INSTALACION\n\n");
        String direccion = UiText.sanitizeDbValue(pedido.optString("direccion_instalacion", ""));
        sb.append(direccion.isEmpty() ? "No disponible" : direccion).append("\n");

        JSONObject fact = pedido.optJSONObject("facturacion");
        if (fact != null) {
            sb.append("\nDATOS FACTURACIÓN\n\n");
            appendLinea(sb, "Nombre Cliente", fact.optString("nombre", ""));
            appendLinea(sb, "Dirección", fact.optString("direccion", ""));
            appendLinea(sb, "Poblacion", fact.optString("poblacion", ""));
            appendLinea(sb, "Telefono", fact.optString("telefono", ""));
        }

        JSONObject entrega = pedido.optJSONObject("entrega");
        if (entrega != null) {
            sb.append("\nDATOS ENTREGA\n\n");
            appendLinea(sb, "Nombre Cliente", entrega.optString("nombre", ""));
            appendLinea(sb, "Dirección", entrega.optString("direccion", ""));
            appendLinea(sb, "Poblacion", entrega.optString("poblacion", ""));
            appendLinea(sb, "Telefono", entrega.optString("telefono", ""));
        }

        sb.append("\nDETALLE DEL PEDIDO\n\n");
        sb.append("CTD\tCódigo\tDescripción\n");
        JSONArray detalle = pedido.optJSONArray("detalle_pedido");
        if (detalle != null && detalle.length() > 0) {
            for (int i = 0; i < detalle.length(); i++) {
                JSONObject row = detalle.optJSONObject(i);
                if (row == null) continue;
                sb.append(row.optInt("product_quantity", 0)).append("\t")
                        .append(UiText.sanitizeDbValue(row.optString("product_reference", ""))).append("\t")
                        .append(UiText.sanitizeDbValue(row.optString("product_name", ""))).append("\n");
            }
        } else {
            sb.append("No disponible\n");
        }

        sb.append("\nOBSERVACIONES DEL CLIENTE EN PEDIDO\n\n");
        String obs = UiText.sanitizeDbValue(pedido.optString("observaciones_pedido", ""));
        sb.append(obs.isEmpty() ? "No disponible" : obs).append("\n");

        sb.append("\nCOMENTARIOS DEL INSTALADOR\n\n");
        JSONArray comentariosInst = pedido.optJSONArray("comentarios_instalador");
        if (comentariosInst != null && comentariosInst.length() > 0) {
            for (int i = 0; i < comentariosInst.length(); i++) {
                JSONObject c = comentariosInst.optJSONObject(i);
                if (c == null) continue;
                sb.append("El ").append(UiText.sanitizeDbValue(c.optString("Fecha", "-")))
                        .append(" ").append(UiText.sanitizeDbValue(c.optString("Usuario", "-")))
                        .append(" escribió: ")
                        .append(UiText.sanitizeDbValue(c.optString("Texto", "-")))
                        .append("\n");
            }
        } else {
            sb.append("No disponible\n");
        }

        JSONObject fotos = pedido.optJSONObject("fotografias");
        sb.append("\nFOTOGRAFIAS APORTADAS POR EL CLIENTE\n\n");
        sb.append(formatListaFotos(fotos, "cliente"));
        sb.append("\n\nFOTOGRAFIAS PREVIAS A LA INSTALACION\n\n");
        sb.append(formatListaFotos(fotos, "previas"));
        sb.append("\n\nFOTOGRAFIAS DE INCIDENCIAS DURANTE LA INSTALACION\n\n");
        sb.append(formatListaFotos(fotos, "incidencias"));
        sb.append("\n\nFOTOGRAFIAS DE LA INSTALACION ACABADA\n\n");
        sb.append(formatListaFotos(fotos, "acabada"));
        sb.append("\n\nFOTOGRAFIAS DOCUMENTOS\n\n");
        sb.append(formatListaFotos(fotos, "documentos"));

        return sb.toString().trim();
    }

    private void appendLinea(StringBuilder sb, String label, String value) {
        sb.append(label).append(": ")
                .append(UiText.displayValue(value, "No disponible"))
                .append("\n");
    }

    private String formatListaFotos(JSONObject fotos, String key) {
        if (fotos == null) return "No disponible";
        JSONArray arr = fotos.optJSONArray(key);
        if (arr == null || arr.length() == 0) return "No disponible";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < arr.length(); i++) {
            String item = UiText.sanitizeDbValue(arr.optString(i, ""));
            if (item.isEmpty()) continue;
            sb.append(item).append("\n");
        }
        return sb.length() == 0 ? "No disponible" : sb.toString().trim();
    }

    private String formatFecha(String raw) {
        String clean = UiText.sanitizeDbValue(raw);
        if (clean.isEmpty()) return "";
        try {
            SimpleDateFormat input = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
            SimpleDateFormat output = new SimpleDateFormat("dd-MM-yyyy HH:mm:ss", Locale.getDefault());
            return output.format(input.parse(clean));
        } catch (ParseException e) {
            return clean;
        }
    }
}
