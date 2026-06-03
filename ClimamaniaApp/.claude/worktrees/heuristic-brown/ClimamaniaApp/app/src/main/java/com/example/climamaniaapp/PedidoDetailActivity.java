package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class PedidoDetailActivity extends BaseActivity {

    private TextView txtReferencia;
    private TextView txtFechaHora;
    private TextView txtCliente;
    private TextView txtDireccion;
    private TextView txtTelefono;
    private TextView txtWhatsapp;
    private TextView txtEquipo;
    private TextView txtObservaciones;
    private TextView txtComentarios;
    private EditText editComentario;
    private Button btnGuardarComentario;
    private TextView txtFotosCliente;
    private LinearLayout llDetallePedido;
    private View sectionEquipo;
    private View sectionDetalle;
    private View sectionObservaciones;
    private View sectionComentarios;
    private View sectionFotos;
    private Button btnFotosCliente;
    private Button btnRealizarInstalacion;
    private ImageButton btnMapa;
    private ImageButton btnLlamar;
    private ImageButton btnWhatsapp;
    private String referenciaActual;
    private String clienteActual;
    private String fotosClienteJson;
    private String direccionActual;
    private String telefonoActual;
    private String whatsappActual;
    private List<String> telefonosDisponibles = new ArrayList<>();

    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String COMENTARIO_URL = "https://app.clminstal.es/api/add_comentario.php";
    private static final String API_KEY = "TEST123";

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_pedido_detail, contentFrame, true);

        setupBottomBar();

        txtReferencia = content.findViewById(R.id.txtPedidoReferencia);
        txtFechaHora = content.findViewById(R.id.txtPedidoFechaHora);
        txtCliente = content.findViewById(R.id.txtPedidoCliente);
        txtDireccion = content.findViewById(R.id.txtPedidoDireccion);
        txtTelefono = content.findViewById(R.id.txtPedidoTelefono);
        txtWhatsapp = content.findViewById(R.id.txtPedidoWhatsapp);
        txtEquipo = content.findViewById(R.id.txtPedidoEquipo);
        txtObservaciones = content.findViewById(R.id.txtPedidoObservaciones);
        txtComentarios = content.findViewById(R.id.txtPedidoComentarios);
        editComentario = content.findViewById(R.id.editPedidoComentario);
        btnGuardarComentario = content.findViewById(R.id.btnPedidoAddComentario);
        txtFotosCliente = content.findViewById(R.id.txtPedidoFotosCliente);
        btnFotosCliente = content.findViewById(R.id.btnPedidoFotosCliente);
        btnRealizarInstalacion = content.findViewById(R.id.btnRealizarInstalacion);
        btnMapa = content.findViewById(R.id.btnDireccionMapa);
        btnLlamar = content.findViewById(R.id.btnTelefonoLlamar);
        btnWhatsapp = content.findViewById(R.id.btnWhatsapp);
        llDetallePedido = content.findViewById(R.id.llPedidoDetalle);
        sectionEquipo = content.findViewById(R.id.sectionEquipo);
        sectionDetalle = content.findViewById(R.id.sectionDetalle);
        sectionObservaciones = content.findViewById(R.id.sectionObservaciones);
        sectionComentarios = content.findViewById(R.id.sectionComentarios);
        sectionFotos = content.findViewById(R.id.sectionFotos);

        Button btnVolver = content.findViewById(R.id.btnPedidoVolver);
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        String json = getIntent().getStringExtra("pedido_json");
        if (json == null || json.trim().isEmpty()) {
            String ref = getIntent().getStringExtra("referencia");
            if (ref == null || ref.trim().isEmpty()) {
                ref = getIntent().getStringExtra("pedido");
            }
            if (ref == null || ref.trim().isEmpty()) {
                android.widget.Toast.makeText(this, "Pedido sin datos", android.widget.Toast.LENGTH_SHORT).show();
                finish();
                return;
            }
            cargarPedido(ref.trim());
        } else {
            try {
                JSONObject pedido = new JSONObject(json);
                renderPedido(pedido);
            } catch (JSONException e) {
                android.widget.Toast.makeText(this, "Error al leer el pedido", android.widget.Toast.LENGTH_SHORT).show();
                finish();
            }
        }

        if (btnFotosCliente != null) {
            btnFotosCliente.setOnClickListener(v -> abrirFotosCliente());
        }
        if (btnRealizarInstalacion != null) {
            btnRealizarInstalacion.setOnClickListener(v -> abrirInstalacion());
        }
        if (btnMapa != null) {
            btnMapa.setOnClickListener(v -> abrirMapa());
        }
        if (btnLlamar != null) {
            btnLlamar.setOnClickListener(v -> llamarTelefono());
        }
        if (btnWhatsapp != null) {
            btnWhatsapp.setOnClickListener(v -> enviarWhatsapp());
        }
        if (btnGuardarComentario != null && editComentario != null) {
            btnGuardarComentario.setOnClickListener(v -> guardarComentarioInstalador());
        }
    }

    private void renderPedido(JSONObject pedido) {
        String referencia = UiText.sanitizeDbValue(pedido.optString("referencia", ""));
        String cliente = UiText.sanitizeDbValue(pedido.optString("cliente", ""));
        String rawDireccion = UiText.sanitizeDbValue(pedido.optString("direccion_instalacion", ""));
        String direccion = cleanDireccionForDisplay(rawDireccion);
        telefonosDisponibles = buildTelefonosPedido(pedido, rawDireccion);
        String telefono = UiText.sanitizeDbValue(chooseBestMobile(telefonosDisponibles));
        String whatsapp = telefono;

        referenciaActual = referencia;
        clienteActual = cliente;
        direccionActual = direccion;
        telefonoActual = telefono.isEmpty() ? null : telefono;
        whatsappActual = whatsapp.isEmpty() ? null : whatsapp;

        UiText.setTextOrPlaceholder(txtReferencia, referencia, "Referencia no disponible");
        if (txtFechaHora != null) {
            String fechaHora = buildFechaHoraPedido(pedido);
            if (fechaHora.isEmpty()) {
                txtFechaHora.setText("");
                txtFechaHora.setVisibility(View.GONE);
            } else {
                txtFechaHora.setText(fechaHora);
                txtFechaHora.setVisibility(View.VISIBLE);
            }
        }
        UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");
        UiText.setTextOrPlaceholder(txtDireccion, direccion, "Dirección no disponible");
        UiText.setLabelOrPlaceholder(txtTelefono, "Teléfono", telefono, "Teléfono no disponible");
        UiText.setLabelOrPlaceholder(txtWhatsapp, "WhatsApp", whatsapp, "WhatsApp no disponible");

        UiText.setTextOrPlaceholder(txtEquipo, buildEquipoTexto(pedido), "Equipo no asignado");
        UiText.setTextOrPlaceholder(txtObservaciones,
                pedido.optString("observaciones_pedido", ""),
                "Observaciones no disponibles");
        UiText.setTextOrPlaceholder(txtComentarios,
                buildComentariosTexto(pedido.optJSONArray("comentarios_instalador")),
                "Comentarios no disponibles");

        populateDetallePedido(pedido.optJSONArray("detalle_pedido"));
        JSONObject fotos = pedido.optJSONObject("fotografias");
        UiText.setTextOrPlaceholder(txtFotosCliente,
                formatFotosLista(fotos, "cliente"),
                "Fotos del cliente no disponibles");
        JSONArray fotosClienteArr = fotos != null ? fotos.optJSONArray("cliente") : null;
        fotosClienteJson = fotosClienteArr != null ? fotosClienteArr.toString() : null;
        if (btnFotosCliente != null) {
            boolean hasFotosCliente = fotosClienteArr != null && fotosClienteArr.length() > 0;
            int color = hasFotosCliente
                    ? androidx.core.content.ContextCompat.getColor(this, android.R.color.holo_green_dark)
                    : androidx.core.content.ContextCompat.getColor(this, R.color.colorPrimary);
            btnFotosCliente.setBackgroundTintList(android.content.res.ColorStateList.valueOf(color));
        }

        updateSectionVisibility();
    }

    private void updateSectionVisibility() {
        if (sectionEquipo != null) {
            sectionEquipo.setVisibility(isMeaningful(txtEquipo) ? View.VISIBLE : View.GONE);
        }
        if (sectionDetalle != null) {
            sectionDetalle.setVisibility(llDetallePedido != null && llDetallePedido.getChildCount() > 0
                    ? View.VISIBLE
                    : View.GONE);
        }
        if (sectionObservaciones != null) {
            sectionObservaciones.setVisibility(isMeaningful(txtObservaciones) ? View.VISIBLE : View.GONE);
        }
        if (sectionComentarios != null) {
            sectionComentarios.setVisibility(
                    isMeaningful(txtComentarios) || editComentario != null || btnGuardarComentario != null
                            ? View.VISIBLE
                            : View.GONE
            );
        }
        if (sectionFotos != null) {
            sectionFotos.setVisibility(isMeaningful(txtFotosCliente) || btnFotosCliente != null
                    ? View.VISIBLE
                    : View.GONE);
        }
        if (txtFotosCliente != null) {
            txtFotosCliente.setVisibility(isMeaningful(txtFotosCliente) ? View.VISIBLE : View.GONE);
        }
    }

    private void guardarComentarioInstalador() {
        if (editComentario == null) return;
        String texto = editComentario.getText().toString().trim();
        if (texto.isEmpty()) {
            android.widget.Toast.makeText(this, "El comentario está vacío", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        if (referenciaActual == null || referenciaActual.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        enviarComentario(referenciaActual.trim(), texto);
    }

    private void enviarComentario(String referencia, String texto) {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombreUsuario = prefs.getString("nombre", "");
        if (nombreUsuario == null || nombreUsuario.trim().isEmpty()) {
            nombreUsuario = prefs.getString("usuario", "Instalador");
        }
        final String usuario = nombreUsuario;

        com.android.volley.RequestQueue queue = com.android.volley.toolbox.Volley.newRequestQueue(this);
        com.android.volley.toolbox.StringRequest request = new com.android.volley.toolbox.StringRequest(
                com.android.volley.Request.Method.POST,
                COMENTARIO_URL,
                response -> {
                    try {
                        org.json.JSONObject root = new org.json.JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            String msg = root.optString("message", "No se pudo guardar");
                            android.widget.Toast.makeText(
                                    PedidoDetailActivity.this,
                                    msg,
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                            return;
                        }
                        appendComentarioLocal(usuario, texto);
                        if (editComentario != null) {
                            editComentario.setText("");
                        }
                        android.widget.Toast.makeText(
                                PedidoDetailActivity.this,
                                "Comentario guardado",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                        updateSectionVisibility();
                    } catch (org.json.JSONException e) {
                        android.widget.Toast.makeText(
                                PedidoDetailActivity.this,
                                "Error al guardar el comentario",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                    }
                },
                error -> android.widget.Toast.makeText(
                        PedidoDetailActivity.this,
                        "Error de conexión al guardar el comentario",
                        android.widget.Toast.LENGTH_SHORT
                ).show()
        ) {
            @Override
            protected java.util.Map<String, String> getParams() {
                java.util.Map<String, String> params = new java.util.HashMap<>();
                params.put("api_key", API_KEY);
                params.put("referencia", referencia);
                params.put("usuario", usuario);
                params.put("texto", texto);
                return params;
            }
        };

        queue.add(request);
    }

    private void appendComentarioLocal(String usuario, String texto) {
        if (txtComentarios == null) return;
        String actual = txtComentarios.getText() != null ? txtComentarios.getText().toString().trim() : "";
        String nuevo = "• " + cleanText(texto);
        if (usuario != null && !usuario.trim().isEmpty()) {
            nuevo = "• " + usuario.trim() + ": " + cleanText(texto);
        }
        if (actual.isEmpty() || actual.equals("-") || actual.toLowerCase(java.util.Locale.ROOT).contains("no disponible")) {
            txtComentarios.setText(nuevo);
        } else {
            txtComentarios.setText(actual + "\n" + nuevo);
        }
    }

    private boolean isMeaningful(TextView tv) {
        if (tv == null) return false;
        String text = tv.getText() != null ? tv.getText().toString().trim() : "";
        return !UiText.isMissingDbValue(text);
    }

    private void cargarPedido(String referencia) {
        try {
            String url = PEDIDO_URL
                    + "?api_key=" + java.net.URLEncoder.encode(API_KEY, "UTF-8")
                    + "&referencia=" + java.net.URLEncoder.encode(referencia.trim(), "UTF-8");

            com.android.volley.RequestQueue queue = com.android.volley.toolbox.Volley.newRequestQueue(this);
            com.android.volley.toolbox.StringRequest request = new com.android.volley.toolbox.StringRequest(
                    com.android.volley.Request.Method.GET,
                    url,
                    response -> {
                        try {
                            org.json.JSONObject root = new org.json.JSONObject(response);
                            if (!root.optBoolean("success", false)) {
                                android.widget.Toast.makeText(
                                        PedidoDetailActivity.this,
                                        root.optString("message", "No se pudo cargar el pedido"),
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                finish();
                                return;
                            }
                            org.json.JSONObject pedido = root.optJSONObject("pedido");
                            if (pedido == null) {
                                android.widget.Toast.makeText(
                                        PedidoDetailActivity.this,
                                        "Pedido sin datos",
                                        android.widget.Toast.LENGTH_SHORT
                                ).show();
                                finish();
                                return;
                            }
                            renderPedido(pedido);
                        } catch (org.json.JSONException e) {
                            android.widget.Toast.makeText(
                                    PedidoDetailActivity.this,
                                    "Error al leer el pedido",
                                    android.widget.Toast.LENGTH_SHORT
                            ).show();
                            finish();
                        }
                    },
                    error -> {
                        android.widget.Toast.makeText(
                                PedidoDetailActivity.this,
                                "Error de conexión al cargar el pedido",
                                android.widget.Toast.LENGTH_SHORT
                        ).show();
                        finish();
                    }
            );
            queue.add(request);
        } catch (Exception e) {
            android.widget.Toast.makeText(
                    this,
                    "Error interno al preparar la petición",
                    android.widget.Toast.LENGTH_SHORT
            ).show();
            finish();
        }
    }

    private void abrirFotosCliente() {
        if (referenciaActual == null || referenciaActual.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        android.content.Intent intent = new android.content.Intent(this, PhotoListActivity.class);
        intent.putExtra("titulo", "Fotos del cliente");
        intent.putExtra("referencia", referenciaActual);
        intent.putExtra("categoria", "cliente");
        intent.putExtra("clave", "FOTOCLI");
        if (fotosClienteJson != null && !fotosClienteJson.trim().isEmpty()) {
            intent.putExtra("fotos_json", fotosClienteJson);
        }
        startActivity(intent);
    }

    private void abrirInstalacion() {
        if (referenciaActual == null || referenciaActual.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        android.content.Intent intent = new android.content.Intent(this, InstallActivity.class);
        intent.putExtra("referencia", referenciaActual);
        if (clienteActual != null) {
            intent.putExtra("cliente", clienteActual);
        }
        startActivity(intent);
    }

    private String buildEquipoTexto(JSONObject pedido) {
        StringBuilder sb = new StringBuilder();
        JSONArray equipos = pedido.optJSONArray("equipo_asignado");
        boolean hasEquipo = false;
        if (equipos != null && equipos.length() > 0) {
            for (int i = 0; i < equipos.length(); i++) {
                JSONObject eq = equipos.optJSONObject(i);
                if (eq == null) continue;
                String desc = cleanText(eq.optString("descripcion", ""));
                String fecha = cleanText(eq.optString("start", ""));
                sb.append("• ")
                        .append(desc.isEmpty() ? "Equipo sin descripción" : desc)
                        .append(" · ")
                        .append(formatFecha(fecha))
                        .append("\n");
                hasEquipo = true;
            }
        }

        JSONArray finalizadas = pedido.optJSONArray("finalizaciones");
        boolean hasFinalizadas = false;
        if (finalizadas != null && finalizadas.length() > 0) {
            for (int i = 0; i < finalizadas.length(); i++) {
                JSONObject fin = finalizadas.optJSONObject(i);
                if (fin == null) continue;
                sb.append("• Finalizada por ")
                        .append(cleanText(fin.optString("Usuario", "-")))
                        .append(" · ")
                        .append(formatFecha(cleanText(fin.optString("Fecha", ""))))
                        .append("\n");
                hasFinalizadas = true;
            }
        }
        if (!hasEquipo && !hasFinalizadas) {
            return "";
        }
        return trimOrDash(sb.toString());
    }

    private List<String> buildTelefonosPedido(JSONObject pedido, String rawDireccion) {
        List<String> phones = new ArrayList<>();

        JSONObject entrega = pedido.optJSONObject("entrega");
        if (entrega != null) {
            phones.addAll(extractPhones(entrega.optString("telefono", "")));
        }

        JSONObject fact = pedido.optJSONObject("facturacion");
        if (fact != null) {
            phones.addAll(extractPhones(fact.optString("telefono", "")));
        }

        if (phones.isEmpty()) {
            phones.addAll(extractPhones(rawDireccion));
        }

        return dedupePhones(phones);
    }

    private void abrirMapa() {
        if (direccionActual == null || direccionActual.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Dirección no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        Uri uri = Uri.parse("geo:0,0?q=" + Uri.encode(direccionActual));
        Intent intent = new Intent(Intent.ACTION_VIEW, uri);
        startActivity(intent);
    }

    private void llamarTelefono() {
        if (telefonosDisponibles == null || telefonosDisponibles.isEmpty()) {
            android.widget.Toast.makeText(this, "Teléfono no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        mostrarSelectorTelefono("Elegir teléfono", telefono -> {
            Intent intent = new Intent(Intent.ACTION_DIAL);
            intent.setData(Uri.parse("tel:" + telefono.trim()));
            startActivity(intent);
        });
    }

    private void enviarWhatsapp() {
        if (telefonosDisponibles == null || telefonosDisponibles.isEmpty()) {
            android.widget.Toast.makeText(this, "Teléfono no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        mostrarSelectorTelefono("Elegir teléfono para WhatsApp", telefono -> {
            android.widget.Toast.makeText(this,
                    "Funcionalidad de WhatsApp pendiente",
                    android.widget.Toast.LENGTH_SHORT).show();
        });
    }

    private interface PhoneSelectionListener {
        void onSelect(String phone);
    }

    private void mostrarSelectorTelefono(String titulo, PhoneSelectionListener onSelect) {
        List<String> phones = telefonosDisponibles != null ? new ArrayList<>(telefonosDisponibles) : new ArrayList<>();
        if (phones.isEmpty()) {
            android.widget.Toast.makeText(this, "Teléfono no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        String lastUsed = getLastUsedPhone();
        if (lastUsed != null && !lastUsed.trim().isEmpty()) {
            phones.remove(lastUsed);
            phones.add(0, lastUsed);
        }
        ArrayAdapter<String> adapter = new ArrayAdapter<String>(this, R.layout.item_phone_option, R.id.txtPhoneValue, phones) {
            @Override
            public View getView(int position, View convertView, android.view.ViewGroup parent) {
                View view = super.getView(position, convertView, parent);
                TextView value = view.findViewById(R.id.txtPhoneValue);
                TextView type = view.findViewById(R.id.txtPhoneType);
                ImageView icon = view.findViewById(R.id.imgPhoneIcon);
                TextView badge = view.findViewById(R.id.txtPhoneBadge);

                String phone = getItem(position);
                if (value != null) {
                    value.setText(phone != null ? phone : "");
                }
                if (type != null) {
                    type.setText(getPhoneTypeLabel(phone));
                }
                if (icon != null) {
                    int tint = isMobilePhone(phone)
                            ? androidx.core.content.ContextCompat.getColor(PedidoDetailActivity.this, R.color.colorPrimary)
                            : androidx.core.content.ContextCompat.getColor(PedidoDetailActivity.this, R.color.colorPrimaryDark);
                    icon.setColorFilter(tint);
                }
                if (badge != null) {
                    String badgeText = getPhoneBadgeLabel(phone, lastUsed);
                    if (badgeText.isEmpty()) {
                        badge.setVisibility(View.GONE);
                    } else {
                        badge.setText(badgeText);
                        badge.setVisibility(View.VISIBLE);
                    }
                }
                return view;
            }
        };

        new androidx.appcompat.app.AlertDialog.Builder(this, R.style.PhoneSelectorDialogTheme)
                .setTitle(titulo)
                .setAdapter(adapter, (dialog, which) -> {
                    String phone = adapter.getItem(which);
                    if (phone != null && onSelect != null) {
                        saveLastUsedPhone(phone);
                        onSelect.onSelect(phone);
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private String getPhoneBadgeLabel(String phone, String lastUsed) {
        if (phone == null || phone.trim().isEmpty()) return "";
        if (lastUsed != null && !lastUsed.trim().isEmpty() && phone.equals(lastUsed)) {
            return "Último usado";
        }
        if (telefonoActual != null && !telefonoActual.trim().isEmpty() && phone.equals(telefonoActual)) {
            return "Principal";
        }
        return "";
    }

    private String getLastUsedPhone() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String key = "last_phone_" + (referenciaActual != null ? referenciaActual : "global");
        return prefs.getString(key, "");
    }

    private void saveLastUsedPhone(String phone) {
        if (phone == null || phone.trim().isEmpty()) return;
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String key = "last_phone_" + (referenciaActual != null ? referenciaActual : "global");
        prefs.edit().putString(key, phone).apply();
    }

    private String getPhoneTypeLabel(String phone) {
        if (phone == null) return "Teléfono";
        String digits = phone.replaceAll("[^0-9]", "");
        if (digits.isEmpty()) return "Teléfono";
        if (digits.startsWith("6") || digits.startsWith("7")) {
            return "Móvil";
        }
        if (digits.startsWith("8") || digits.startsWith("9")) {
            return "Fijo";
        }
        return "Teléfono";
    }

    private boolean isMobilePhone(String phone) {
        if (phone == null) return false;
        String digits = phone.replaceAll("[^0-9]", "");
        return digits.startsWith("6") || digits.startsWith("7");
    }

    private String buildFechaHoraPedido(JSONObject pedido) {
        JSONArray equipos = pedido.optJSONArray("equipo_asignado");
        if (equipos != null) {
            for (int i = 0; i < equipos.length(); i++) {
                JSONObject eq = equipos.optJSONObject(i);
                if (eq == null) continue;
                String fecha = UiText.sanitizeDbValue(eq.optString("start", ""));
                String formatted = formatFechaHoraCorta(fecha);
                if (!formatted.isEmpty()) {
                    return formatted;
                }
            }
        }
        return "";
    }

    private String formatFechaHoraCorta(String raw) {
        String clean = UiText.sanitizeDbValue(raw);
        if (clean.isEmpty()) return "";
        try {
            java.text.SimpleDateFormat input = new java.text.SimpleDateFormat(
                    "yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault());
            java.text.SimpleDateFormat output = new java.text.SimpleDateFormat(
                    "EEE d MMM · HH:mm", java.util.Locale.forLanguageTag("es-ES"));
            java.util.Date date = input.parse(clean);
            if (date == null) return "";
            return output.format(date);
        } catch (Exception e) {
            return "";
        }
    }

    private String buildAgendaTexto(JSONObject pedido) {
        JSONObject agenda = pedido.optJSONObject("articulos_agenda");
        String detalles = agenda != null ? agenda.optString("detalles", "") : "";
        String comentarios = agenda != null ? agenda.optString("comentarios", "") : "";
        StringBuilder sb = new StringBuilder();
        if (!detalles.isEmpty()) {
            sb.append("• ").append(cleanText(detalles)).append("\n");
        }
        if (!comentarios.isEmpty()) {
            sb.append("• ").append(cleanText(comentarios)).append("\n");
        }
        return trimOrDash(sb.toString());
    }

    private String buildFichaTexto(JSONObject ficha) {
        if (ficha == null) return "-";
        List<String> lines = new ArrayList<>();
        addLinea(lines, "Nombre", ficha.optString("nombre", ""));
        addLinea(lines, "Dirección", ficha.optString("direccion", ""));
        addLinea(lines, "Población", ficha.optString("poblacion", ""));
        addLinea(lines, "Teléfono", ficha.optString("telefono", ""));
        return lines.isEmpty() ? "-" : joinLines(lines);
    }

    private void populateDetallePedido(@Nullable JSONArray detalle) {
        llDetallePedido.removeAllViews();
        if (detalle == null || detalle.length() == 0) {
            llDetallePedido.addView(simpleLine("Sin artículos"));
            return;
        }

        llDetallePedido.addView(buildDetalleRow("CTD", "Código", "Descripción", true));

        for (int i = 0; i < detalle.length(); i++) {
            JSONObject row = detalle.optJSONObject(i);
            if (row == null) continue;
            String qty = String.valueOf(row.optInt("product_quantity", 0));
            String code = UiText.displayValue(row.optString("product_reference", ""), "Sin datos");
            String desc = UiText.displayValue(row.optString("product_name", ""), "Sin datos");
            llDetallePedido.addView(buildDetalleRow(qty, code, desc, false));
        }
    }

    private View buildDetalleRow(String qty, String code, String desc, boolean header) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(dp(8), dp(8), dp(8), dp(8));
        if (header) {
            row.setBackgroundColor(0x14F28C3A);
        }

        TextView colQty = new TextView(this);
        TextView colCode = new TextView(this);
        TextView colDesc = new TextView(this);

        colQty.setText(qty);
        colCode.setText(code);
        colDesc.setText(desc);

        colQty.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 0.7f));
        colCode.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.3f));
        colDesc.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 3.0f));

        float textSize = header ? 16f : 15f;
        colQty.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSize);
        colCode.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSize);
        colDesc.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSize);

        int color = header ? 0xFF212121 : 0xFF424242;
        colQty.setTextColor(color);
        colCode.setTextColor(color);
        colDesc.setTextColor(color);

        if (header) {
            colQty.setTypeface(null, Typeface.BOLD);
            colCode.setTypeface(null, Typeface.BOLD);
            colDesc.setTypeface(null, Typeface.BOLD);
        }

        row.addView(colQty);
        row.addView(colCode);
        row.addView(colDesc);
        return row;
    }

    private String buildComentariosTexto(@Nullable JSONArray comentarios) {
        if (comentarios == null || comentarios.length() == 0) return "-";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < comentarios.length(); i++) {
            JSONObject c = comentarios.optJSONObject(i);
            if (c == null) continue;
            sb.append("• ")
                    .append(UiText.sanitizeDbValue(c.optString("Fecha", "-")))
                    .append(" · ")
                    .append(UiText.sanitizeDbValue(c.optString("Usuario", "-")))
                    .append(": ")
                    .append(cleanText(c.optString("Texto", "-")))
                    .append("\n");
        }
        return trimOrDash(sb.toString());
    }

    private String formatFotosLista(JSONObject fotos, String key) {
        if (fotos == null) return "-";
        JSONArray arr = fotos.optJSONArray(key);
        if (arr == null || arr.length() == 0) return "-";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < arr.length(); i++) {
            String item = UiText.sanitizeDbValue(arr.optString(i, ""));
            if (item.isEmpty()) continue;
            sb.append("• ").append(item).append("\n");
        }
        return trimOrDash(sb.toString());
    }

    private String normalizeEmpty(String text) {
        String clean = cleanText(text);
        return clean;
    }

    private String cleanText(String raw) {
        if (raw == null) return "";
        String cleaned = raw.replace("<br>", "\n")
                .replace("<br/>", "\n")
                .replace("<br />", "\n")
                .replace("</br>", "\n")
                .replace("</BR>", "\n")
                .replace("\r", "")
                .trim();
        return UiText.sanitizeDbValue(cleaned);
    }

    private String cleanDireccionForDisplay(String raw) {
        String cleaned = cleanText(raw);
        if (cleaned.isEmpty()) return "";

        String[] lines = cleaned.split("\n+");
        StringBuilder sb = new StringBuilder();
        for (String line : lines) {
            String l = line == null ? "" : line.trim();
            if (l.isEmpty()) continue;
            String lower = l.toLowerCase(java.util.Locale.ROOT);
            if (lower.contains("tel") || lower.contains("whatsapp")) {
                continue;
            }
            if (looksLikePhoneLine(l)) {
                continue;
            }
            if (sb.length() > 0) sb.append("\n");
            sb.append(l);
        }
        return sb.toString().trim();
    }

    private boolean looksLikePhoneLine(String line) {
        String digits = line.replaceAll("\\D", "");
        return digits.length() >= 9 && digits.length() <= 13;
    }

    private String extractPhoneFromText(String raw) {
        List<String> phones = extractPhones(raw);
        String best = chooseBestMobile(phones);
        return best != null ? best : "";
    }

    private List<String> extractPhones(String raw) {
        List<String> result = new ArrayList<>();
        String cleaned = cleanText(raw);
        if (cleaned.isEmpty()) return result;

        // Extrae tokens numéricos para evitar concatenar varios teléfonos en uno
        String normalized = cleaned.replaceAll("[^\\d+]", " ");
        String[] tokens = normalized.trim().split("\\s+");
        for (String token : tokens) {
            if (token == null || token.trim().isEmpty()) continue;
            String digits = token.replaceAll("\\D", "");
            if (digits.length() >= 9 && digits.length() <= 13) {
                result.add(token.trim());
            }
        }
        return result;
    }

    private String chooseBestMobile(List<String> phones) {
        if (phones == null || phones.isEmpty()) return null;

        // Prefer mobiles starting with 6 or 7
        for (String phone : phones) {
            String digits = phone.replaceAll("\\D", "");
            if (digits.startsWith("6") || digits.startsWith("7")) {
                return phone;
            }
        }

        // Fallback to first available
        return phones.get(0);
    }

    private List<String> dedupePhones(List<String> phones) {
        List<String> result = new ArrayList<>();
        java.util.HashSet<String> seen = new java.util.HashSet<>();
        for (String phone : phones) {
            if (phone == null) continue;
            String digits = phone.replaceAll("\\D", "");
            if (digits.isEmpty()) continue;
            if (seen.add(digits)) {
                result.add(phone);
            }
        }
        return result;
    }

    private void addLinea(List<String> lines, String label, String value) {
        String clean = cleanText(value);
        if (clean.isEmpty()) return;
        lines.add(label + ": " + clean);
    }

    private String joinLines(List<String> lines) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lines.size(); i++) {
            if (i > 0) sb.append("\n");
            sb.append(lines.get(i));
        }
        return sb.toString();
    }

    private String trimOrDash(String text) {
        String clean = UiText.sanitizeDbValue(text);
        return clean.isEmpty() ? "-" : clean;
    }

    private TextView simpleLine(String text) {
        TextView tv = new TextView(this);
        tv.setText(text);
        tv.setTextColor(0xFF616161);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f);
        tv.setPadding(dp(8), dp(6), dp(8), dp(6));
        return tv;
    }

    private String formatFecha(String raw) {
        String clean = cleanText(raw);
        if (clean.isEmpty()) return "-";
        return clean.replace("T", " ").replace(".000", "");
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
