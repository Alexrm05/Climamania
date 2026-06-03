package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.RelativeSizeSpan;
import android.text.style.StyleSpan;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

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
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class MainActivity extends BaseActivity {

    TextView txtWelcome, txtSubtitulo;

    private TextView txtInstEnCurso;
    private TextView txtProxima;
    private TextView txtInstEnCursoMeta;
    private TextView txtProximaMeta;
    private TextView txtInstEnCursoDireccion;
    private TextView txtProximaDireccion;
    private View btnLlamarInstEnCurso;
    private View btnLlamarProxima;
    private View btnMapaInstEnCurso;
    private View btnMapaProxima;
    private View btnWhatsappInstEnCurso;
    private View btnWhatsappProxima;
    private Button btnVisitasPendientes;
    private Button btnIncidenciasPendientes;
    private String refEnCurso;
    private String refProxima;
    private String telefonoEnCurso;
    private String telefonoProxima;
    private String direccionEnCurso;
    private String direccionProxima;
    private String whatsappEnCurso;
    private String whatsappProxima;
    private Bundle extrasInstEnCurso;
    private Bundle extrasProxima;

    private static final String EVENTS_URL = "https://app.clminstal.es/api/get_events.php";
    private static final String VISITAS_PENDIENTES_URL = "https://app.clminstal.es/api/get_visitas_pendientes.php";
    private static final String INCIDENCIAS_PENDIENTES_URL = "https://app.clminstal.es/api/get_incidencias_pendientes.php";
    private static final String API_KEY = "TEST123";
    private static final String INSTALL_WEB_BASE = "https://app.clminstal.es/gestion_instalacion.php?ref=";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View mainContent = getLayoutInflater().inflate(R.layout.activity_main, contentFrame, true);

        // Pequeña animación de aparición del contenido principal
        mainContent.setAlpha(0f);
        mainContent.animate().alpha(1f).setDuration(220).start();

        setupBottomBar();

        txtWelcome = mainContent.findViewById(R.id.txtWelcome);
        txtSubtitulo = mainContent.findViewById(R.id.txtSubtitulo);
        txtInstEnCurso = mainContent.findViewById(R.id.txtInstalacionEnCurso);
        txtProxima = mainContent.findViewById(R.id.txtProximaInstalacion);
        txtInstEnCursoMeta = mainContent.findViewById(R.id.txtInstEnCursoMeta);
        txtProximaMeta = mainContent.findViewById(R.id.txtProximaMeta);
        txtInstEnCursoDireccion = mainContent.findViewById(R.id.txtInstEnCursoDireccion);
        txtProximaDireccion = mainContent.findViewById(R.id.txtProximaDireccion);
        btnLlamarInstEnCurso = mainContent.findViewById(R.id.btnLlamarInstEnCurso);
        btnLlamarProxima = mainContent.findViewById(R.id.btnLlamarProxima);
        btnMapaInstEnCurso = mainContent.findViewById(R.id.btnMapaInstEnCurso);
        btnMapaProxima = mainContent.findViewById(R.id.btnMapaProxima);
        btnWhatsappInstEnCurso = mainContent.findViewById(R.id.btnWhatsappInstEnCurso);
        btnWhatsappProxima = mainContent.findViewById(R.id.btnWhatsappProxima);
        btnVisitasPendientes = mainContent.findViewById(R.id.btnVisitasPendientes);
        btnIncidenciasPendientes = mainContent.findViewById(R.id.btnIncidenciasPendientes);

        View layoutSearch = mainContent.findViewById(R.id.layoutSearch);
        View layoutResumen = mainContent.findViewById(R.id.layoutResumen);
        applyStaggeredEntrance(layoutSearch, layoutResumen);

        // Personalizar saludo con el nombre real del usuario (si está guardado)
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = prefs.getString("nombre", "");
        String usuario = prefs.getString("usuario", "");
        String displayName;
        if (nombre != null && !nombre.trim().isEmpty()) {
            displayName = nombre.trim();
        } else if (usuario != null && !usuario.trim().isEmpty()) {
            displayName = usuario.trim();
        } else {
            displayName = "instalador";
        }

        String saludo = "Bienvenido " + displayName;
        SpannableString styledSaludo = new SpannableString(saludo);
        int startName = saludo.indexOf(displayName);
        if (startName >= 0) {
            styledSaludo.setSpan(
                    new ForegroundColorSpan(Color.BLACK),
                    startName,
                    startName + displayName.length(),
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
        txtWelcome.setText(styledSaludo);
        if (txtSubtitulo != null) {
            txtSubtitulo.setText("");
            txtSubtitulo.setVisibility(View.GONE);
        }

        // Resumen de instalaciones: en curso y próxima
        cargarResumenInstalaciones();
        cargarVisitasPendientes();
        cargarIncidenciasPendientes();

        // Buscador de eventos
        EditText editSearchQuery = mainContent.findViewById(R.id.editSearchQuery);
        Button btnSearchEvents = mainContent.findViewById(R.id.btnSearchEvents);

        btnSearchEvents.setOnClickListener(v -> {
            String query = editSearchQuery.getText().toString().trim();
            if (query.isEmpty()) {
                Toast.makeText(MainActivity.this,
                        "Introduce un dato para buscar",
                        Toast.LENGTH_SHORT).show();
                return;
            }
            Intent intent = new Intent(MainActivity.this, SearchEventsActivity.class);
            intent.putExtra("query", query);
            startActivity(intent);
        });

        if (btnLlamarInstEnCurso != null) {
            btnLlamarInstEnCurso.setOnClickListener(v -> llamarNumero(telefonoEnCurso));
        }
        if (btnLlamarProxima != null) {
            btnLlamarProxima.setOnClickListener(v -> llamarNumero(telefonoProxima));
        }
        if (btnMapaInstEnCurso != null) {
            btnMapaInstEnCurso.setOnClickListener(v -> abrirMapaDireccion(direccionEnCurso));
        }
        if (btnMapaProxima != null) {
            btnMapaProxima.setOnClickListener(v -> abrirMapaDireccion(direccionProxima));
        }
        if (btnWhatsappInstEnCurso != null) {
            btnWhatsappInstEnCurso
                    .setOnClickListener(v -> enviarWhatsapp(resolveWhatsapp(whatsappEnCurso, telefonoEnCurso)));
        }
        if (btnWhatsappProxima != null) {
            btnWhatsappProxima
                    .setOnClickListener(v -> enviarWhatsapp(resolveWhatsapp(whatsappProxima, telefonoProxima)));
        }
        if (btnVisitasPendientes != null) {
            btnVisitasPendientes.setOnClickListener(v -> abrirVisitasWeb());
        }
        if (btnIncidenciasPendientes != null) {
            btnIncidenciasPendientes.setOnClickListener(v -> abrirIncidenciasPendientes());
        }
    }

    private void cargarResumenInstalaciones() {
        if (txtInstEnCurso != null) {
            txtInstEnCurso.setText("Instalación en curso: cargando...");
        }
        if (txtProxima != null) {
            txtProxima.setText("Próxima instalación: cargando...");
        }
        if (txtInstEnCursoMeta != null) {
            txtInstEnCursoMeta.setText("");
            txtInstEnCursoMeta.setVisibility(View.GONE);
        }
        if (txtProximaMeta != null) {
            txtProximaMeta.setText("");
            txtProximaMeta.setVisibility(View.GONE);
        }
        if (txtInstEnCursoDireccion != null) {
            txtInstEnCursoDireccion.setText("");
        }
        if (txtProximaDireccion != null) {
            txtProximaDireccion.setText("");
        }
        telefonoEnCurso = null;
        telefonoProxima = null;
        extrasInstEnCurso = null;
        extrasProxima = null;

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
                    response -> handleResumenResponse(response),
                    error -> {
                        String msg = "No se pudieron cargar las instalaciones";
                        if (txtInstEnCurso != null)
                            txtInstEnCurso.setText("Instalación en curso: " + msg);
                        if (txtProxima != null)
                            txtProxima.setText("Próxima instalación: " + msg);
                        if (txtInstEnCursoMeta != null) {
                            txtInstEnCursoMeta.setText("");
                            txtInstEnCursoMeta.setVisibility(View.GONE);
                        }
                        if (txtProximaMeta != null) {
                            txtProximaMeta.setText("");
                            txtProximaMeta.setVisibility(View.GONE);
                        }
                        if (txtInstEnCursoDireccion != null)
                            txtInstEnCursoDireccion.setText("");
                        if (txtProximaDireccion != null)
                            txtProximaDireccion.setText("");
                        telefonoEnCurso = null;
                        telefonoProxima = null;
                        extrasInstEnCurso = null;
                        extrasProxima = null;
                    });

            queue.add(request);
        } catch (Exception e) {
            if (txtInstEnCurso != null)
                txtInstEnCurso.setText("Instalación en curso: error interno");
            if (txtProxima != null)
                txtProxima.setText("Próxima instalación: error interno");
            if (txtInstEnCursoMeta != null) {
                txtInstEnCursoMeta.setText("");
                txtInstEnCursoMeta.setVisibility(View.GONE);
            }
            if (txtProximaMeta != null) {
                txtProximaMeta.setText("");
                txtProximaMeta.setVisibility(View.GONE);
            }
            if (txtInstEnCursoDireccion != null)
                txtInstEnCursoDireccion.setText("");
            if (txtProximaDireccion != null)
                txtProximaDireccion.setText("");
            telefonoEnCurso = null;
            telefonoProxima = null;
            direccionEnCurso = null;
            direccionProxima = null;
            whatsappEnCurso = null;
            whatsappProxima = null;
            extrasInstEnCurso = null;
            extrasProxima = null;
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
            // Legacy int stored in prefs
        }
        return String.valueOf(prefs.getInt("equipoInstaladores", 0));
    }

    private void applyStaggeredEntrance(View... views) {
        int delay = 60;
        int current = 0;
        for (View v : views) {
            if (v == null)
                continue;
            v.setAlpha(0f);
            v.setTranslationY(dp(6));
            v.animate()
                    .alpha(1f)
                    .translationY(0f)
                    .setDuration(220)
                    .setStartDelay(current)
                    .setInterpolator(new android.view.animation.DecelerateInterpolator())
                    .start();
            current += delay;
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void handleResumenResponse(String response) {
        SimpleDateFormat serverDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
        SimpleDateFormat hourFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());
        SimpleDateFormat dayFormat = new SimpleDateFormat("EEE d MMM", Locale.forLanguageTag("es-ES"));

        Calendar now = Calendar.getInstance();

        Date enCursoStart = null, enCursoEnd = null;
        String enCursoRef = null, enCursoCliente = null;
        String enCursoDireccion = null, enCursoTelefono = null;
        String enCursoWhatsapp = null, enCursoEquipo = null;
        String enCursoEstado = null;
        String enCursoDetalles = null, enCursoComentarios = null;
        String enCursoConcertada = null, enCursoEmail = null, enCursoColor = null;

        Date proximaStart = null, proximaEnd = null;
        String proximaRef = null, proximaCliente = null;
        String proximaDireccion = null, proximaTelefono = null;
        String proximaWhatsapp = null, proximaEquipo = null;
        String proximaEstado = null;
        String proximaDetalles = null, proximaComentarios = null;
        String proximaConcertada = null, proximaEmail = null, proximaColor = null;

        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String msg = root.optString("message", "sin datos");
                if (txtInstEnCurso != null)
                    txtInstEnCurso.setText("Instalación en curso: " + msg);
                if (txtProxima != null)
                    txtProxima.setText("Próxima instalación: " + msg);
                if (txtInstEnCursoMeta != null) {
                    txtInstEnCursoMeta.setText("");
                    txtInstEnCursoMeta.setVisibility(View.GONE);
                }
                if (txtProximaMeta != null) {
                    txtProximaMeta.setText("");
                    txtProximaMeta.setVisibility(View.GONE);
                }
                if (txtInstEnCursoDireccion != null)
                    txtInstEnCursoDireccion.setText("");
                if (txtProximaDireccion != null)
                    txtProximaDireccion.setText("");
                telefonoEnCurso = null;
                telefonoProxima = null;
                direccionEnCurso = null;
                direccionProxima = null;
                whatsappEnCurso = null;
                whatsappProxima = null;
                return;
            }
            JSONArray eventos = root.optJSONArray("eventos");
            if (eventos == null || eventos.length() == 0) {
                if (txtInstEnCurso != null)
                    txtInstEnCurso.setText("Instalación en curso: ninguna");
                if (txtProxima != null)
                    txtProxima.setText("Próxima instalación: ninguna");
                if (txtInstEnCursoMeta != null) {
                    txtInstEnCursoMeta.setText("");
                    txtInstEnCursoMeta.setVisibility(View.GONE);
                }
                if (txtProximaMeta != null) {
                    txtProximaMeta.setText("");
                    txtProximaMeta.setVisibility(View.GONE);
                }
                if (txtInstEnCursoDireccion != null)
                    txtInstEnCursoDireccion.setText("");
                if (txtProximaDireccion != null)
                    txtProximaDireccion.setText("");
                telefonoEnCurso = null;
                telefonoProxima = null;
                direccionEnCurso = null;
                direccionProxima = null;
                whatsappEnCurso = null;
                whatsappProxima = null;
                return;
            }

            for (int i = 0; i < eventos.length(); i++) {
                JSONObject ev = eventos.getJSONObject(i);

                String startStr = UiText.sanitizeDbValue(ev.optString("start", ""));
                String endStr = UiText.sanitizeDbValue(ev.optString("end", ""));
                String ref = UiText.sanitizeDbValue(ev.optString("referencia", ""));
                String cliente = UiText.sanitizeDbValue(ev.optString("nombrecliente", ""));
                String direccion = UiText.sanitizeDbValue(ev.optString("direccion", ""));
                String telefono = UiText.sanitizeDbValue(ev.optString("telefono", ""));
                String whatsapp = UiText.sanitizeDbValue(ev.optString("whatsapp", ""));
                String equipo = UiText.sanitizeDbValue(ev.optString("equipo_instaladores", ""));
                String estado = UiText.sanitizeDbValue(ev.optString("estado", ""));
                String detalles = UiText.sanitizeDbValue(ev.optString("detalles", ""));
                String comentarios = UiText.sanitizeDbValue(ev.optString("comentarios", ""));
                String concertada = UiText.sanitizeDbValue(ev.optString("concertada", ""));
                String emailEquipo = UiText.sanitizeDbValue(ev.optString("EmailEquipo", ""));
                String colorHex = UiText.sanitizeDbValue(ev.optString("color", ""));

                if (startStr.isEmpty())
                    continue;

                Date startDate;
                Date endDate;
                try {
                    startDate = serverDateFormat.parse(startStr);
                    if (endStr != null && !endStr.isEmpty()) {
                        endDate = serverDateFormat.parse(endStr);
                    } else {
                        Calendar tmp = Calendar.getInstance();
                        tmp.setTime(startDate);
                        tmp.add(Calendar.HOUR_OF_DAY, 1);
                        endDate = tmp.getTime();
                    }
                } catch (ParseException e) {
                    continue;
                }

                Calendar startCal = Calendar.getInstance();
                startCal.setTime(startDate);
                Calendar endCal = Calendar.getInstance();
                endCal.setTime(endDate);

                boolean isEnCurso = !now.before(startCal) && now.before(endCal);
                boolean isFutura = startCal.after(now);

                if (isEnCurso) {
                    if (enCursoStart == null || startDate.before(enCursoStart)) {
                        enCursoStart = startDate;
                        enCursoEnd = endDate;
                        enCursoRef = ref;
                        enCursoCliente = cliente;
                        enCursoDireccion = direccion;
                        enCursoTelefono = telefono;
                        enCursoWhatsapp = whatsapp;
                        enCursoEquipo = equipo;
                        enCursoEstado = estado;
                        enCursoDetalles = detalles;
                        enCursoComentarios = comentarios;
                        enCursoConcertada = concertada;
                        enCursoEmail = emailEquipo;
                        enCursoColor = colorHex;
                    }
                } else if (isFutura) {
                    if (proximaStart == null || startDate.before(proximaStart)) {
                        proximaStart = startDate;
                        proximaEnd = endDate;
                        proximaRef = ref;
                        proximaCliente = cliente;
                        proximaDireccion = direccion;
                        proximaTelefono = telefono;
                        proximaWhatsapp = whatsapp;
                        proximaEquipo = equipo;
                        proximaEstado = estado;
                        proximaDetalles = detalles;
                        proximaComentarios = comentarios;
                        proximaConcertada = concertada;
                        proximaEmail = emailEquipo;
                        proximaColor = colorHex;
                    }
                }
            }

            if (enCursoRef != null && enCursoStart != null && enCursoEnd != null) {
                // Cabecera: REFERENCIA - Cliente, en naranja y grande
                StringBuilder header = new StringBuilder();
                if (enCursoRef != null && !enCursoRef.trim().isEmpty()) {
                    header.append(enCursoRef.trim());
                }
                if (enCursoCliente != null && !enCursoCliente.trim().isEmpty()) {
                    if (header.length() > 0)
                        header.append(" - ");
                    header.append(enCursoCliente.trim());
                }
                if (header.length() == 0) {
                    header.append("Instalación en curso");
                }
                if (txtInstEnCurso != null) {
                    String headerStr = header.toString();
                    SpannableString span = new SpannableString(headerStr);
                    int orange = ContextCompat.getColor(this, R.color.colorPrimary);
                    int black = Color.BLACK;

                    if (enCursoRef != null && !enCursoRef.trim().isEmpty()) {
                        String refTrim = enCursoRef.trim();
                        int refStart = headerStr.indexOf(refTrim);
                        if (refStart >= 0) {
                            span.setSpan(
                                    new ForegroundColorSpan(orange),
                                    refStart,
                                    refStart + refTrim.length(),
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                            span.setSpan(
                                    new RelativeSizeSpan(1.2f),
                                    refStart,
                                    refStart + refTrim.length(),
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                        }
                    }
                    if (enCursoCliente != null && !enCursoCliente.trim().isEmpty()) {
                        String cliTrim = enCursoCliente.trim();
                        int cliStart = headerStr.lastIndexOf(cliTrim);
                        if (cliStart >= 0) {
                            span.setSpan(
                                    new ForegroundColorSpan(black),
                                    cliStart,
                                    cliStart + cliTrim.length(),
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                        }
                    }
                    txtInstEnCurso.setText(span);
                }

                String dirLimpia = (enCursoDireccion != null && !enCursoDireccion.trim().isEmpty())
                        ? limpiarDireccion(enCursoDireccion)
                        : "";
                String telClean = (enCursoTelefono != null && !enCursoTelefono.trim().isEmpty())
                        ? enCursoTelefono.trim()
                        : "";

                if (txtInstEnCursoDireccion != null) {
                    if (!dirLimpia.isEmpty() || !telClean.isEmpty()) {
                        txtInstEnCursoDireccion.setText(buildDetalleDireccion(dirLimpia, telClean));
                    } else {
                        txtInstEnCursoDireccion.setText(UiText.placeholderSpan("Dirección no disponible"));
                    }
                }
                telefonoEnCurso = telClean.isEmpty() ? null : telClean;
                direccionEnCurso = dirLimpia.isEmpty() ? enCursoDireccion : dirLimpia;
                whatsappEnCurso = enCursoWhatsapp;

                String horaRango = hourFormat.format(enCursoStart) + " - " + hourFormat.format(enCursoEnd);
                extrasInstEnCurso = buildDetalleExtras(
                        horaRango,
                        enCursoRef,
                        enCursoCliente,
                        dirLimpia.isEmpty() ? enCursoDireccion : dirLimpia,
                        telClean,
                        enCursoWhatsapp,
                        enCursoEquipo,
                        enCursoEstado,
                        enCursoDetalles,
                        enCursoComentarios,
                        enCursoConcertada,
                        enCursoEmail,
                        enCursoColor);

                refEnCurso = enCursoRef;
                View card = findViewById(R.id.cardInstEnCursoResumen);
                View.OnClickListener openDetalleEnCurso = v -> abrirDetalleInstalacion(extrasInstEnCurso, refEnCurso);
                if (card != null) {
                    card.setOnClickListener(openDetalleEnCurso);
                } else if (txtInstEnCurso != null) {
                    txtInstEnCurso.setOnClickListener(openDetalleEnCurso);
                }
            } else {
                if (txtInstEnCurso != null)
                    txtInstEnCurso.setText("Instalación en curso: ninguna ahora mismo");
                if (txtInstEnCursoDireccion != null)
                    txtInstEnCursoDireccion.setText("");
                refEnCurso = null;
                telefonoEnCurso = null;
                direccionEnCurso = null;
                whatsappEnCurso = null;
                extrasInstEnCurso = null;
            }

            if (proximaRef != null && proximaStart != null && proximaEnd != null) {
                StringBuilder header = new StringBuilder();
                if (proximaRef != null && !proximaRef.trim().isEmpty()) {
                    header.append(proximaRef.trim());
                }
                if (proximaCliente != null && !proximaCliente.trim().isEmpty()) {
                    if (header.length() > 0)
                        header.append(" - ");
                    header.append(proximaCliente.trim());
                }
                if (header.length() == 0) {
                    header.append("Próxima instalación");
                }
                if (txtProxima != null) {
                    String headerStr = header.toString();
                    SpannableString span = new SpannableString(headerStr);
                    int orange = ContextCompat.getColor(this, R.color.colorPrimary);
                    int black = Color.BLACK;

                    if (proximaRef != null && !proximaRef.trim().isEmpty()) {
                        String refTrim = proximaRef.trim();
                        int refStart = headerStr.indexOf(refTrim);
                        if (refStart >= 0) {
                            span.setSpan(
                                    new ForegroundColorSpan(orange),
                                    refStart,
                                    refStart + refTrim.length(),
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                            span.setSpan(
                                    new RelativeSizeSpan(1.2f),
                                    refStart,
                                    refStart + refTrim.length(),
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                        }
                    }
                    if (proximaCliente != null && !proximaCliente.trim().isEmpty()) {
                        String cliTrim = proximaCliente.trim();
                        int cliStart = headerStr.lastIndexOf(cliTrim);
                        if (cliStart >= 0) {
                            span.setSpan(
                                    new ForegroundColorSpan(black),
                                    cliStart,
                                    cliStart + cliTrim.length(),
                                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                        }
                    }
                    txtProxima.setText(span);
                }

                String dirLimpiaProx = (proximaDireccion != null && !proximaDireccion.trim().isEmpty())
                        ? limpiarDireccion(proximaDireccion)
                        : "";
                String telCleanProx = (proximaTelefono != null && !proximaTelefono.trim().isEmpty())
                        ? proximaTelefono.trim()
                        : "";

                if (txtProximaDireccion != null) {
                    if (!dirLimpiaProx.isEmpty() || !telCleanProx.isEmpty()) {
                        txtProximaDireccion.setText(buildDetalleDireccion(dirLimpiaProx, telCleanProx));
                    } else {
                        txtProximaDireccion.setText(UiText.placeholderSpan("Dirección no disponible"));
                    }
                }
                telefonoProxima = telCleanProx.isEmpty() ? null : telCleanProx;
                direccionProxima = dirLimpiaProx.isEmpty() ? proximaDireccion : dirLimpiaProx;
                whatsappProxima = proximaWhatsapp;

                String horaRangoProx = hourFormat.format(proximaStart) + " - " + hourFormat.format(proximaEnd);
                extrasProxima = buildDetalleExtras(
                        horaRangoProx,
                        proximaRef,
                        proximaCliente,
                        dirLimpiaProx.isEmpty() ? proximaDireccion : dirLimpiaProx,
                        telCleanProx,
                        proximaWhatsapp,
                        proximaEquipo,
                        proximaEstado,
                        proximaDetalles,
                        proximaComentarios,
                        proximaConcertada,
                        proximaEmail,
                        proximaColor);

                refProxima = proximaRef;
                View cardProx = findViewById(R.id.cardProximaResumen);
                View.OnClickListener openDetalleProxima = v -> abrirDetalleInstalacion(extrasProxima, refProxima);
                if (cardProx != null) {
                    cardProx.setOnClickListener(openDetalleProxima);
                } else if (txtProxima != null) {
                    txtProxima.setOnClickListener(openDetalleProxima);
                }
            } else {
                if (txtProxima != null)
                    txtProxima.setText("Próxima instalación: ninguna programada");
                if (txtProximaDireccion != null)
                    txtProximaDireccion.setText("");
                refProxima = null;
                telefonoProxima = null;
                direccionProxima = null;
                whatsappProxima = null;
                extrasProxima = null;
            }

        } catch (JSONException e) {
            if (txtInstEnCurso != null)
                txtInstEnCurso.setText("Instalación en curso: error al leer datos");
            if (txtProxima != null)
                txtProxima.setText("Próxima instalación: error al leer datos");
            if (txtInstEnCursoDireccion != null)
                txtInstEnCursoDireccion.setText("");
            if (txtProximaDireccion != null)
                txtProximaDireccion.setText("");
            telefonoEnCurso = null;
            telefonoProxima = null;
            direccionEnCurso = null;
            direccionProxima = null;
            whatsappEnCurso = null;
            whatsappProxima = null;
        }
    }

    private void cargarVisitasPendientes() {
        if (btnVisitasPendientes == null) {
            return;
        }
        btnVisitasPendientes.setText("Cargando visitas pendientes...");
        btnVisitasPendientes.setVisibility(View.VISIBLE);

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipoStr = readEquipoFromPrefs(prefs);

        try {
            String url = VISITAS_PENDIENTES_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipoStr, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();
            android.util.Log.d("MainActivity", "Visitas pendientes request rol=" + rol
                    + " usuario=" + usuario + " equipo=" + equipoStr);

            RequestQueue queue = Volley.newRequestQueue(this);
            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> handleVisitasPendientesResponse(response),
                    error -> {
                        if (btnVisitasPendientes != null) {
                            btnVisitasPendientes.setText("Visitas pendientes no disponibles");
                            btnVisitasPendientes.setVisibility(View.VISIBLE);
                        }
                    });
            request.setShouldCache(false);
            queue.add(request);
        } catch (Exception e) {
            if (btnVisitasPendientes != null) {
                btnVisitasPendientes.setText("Visitas pendientes no disponibles");
                btnVisitasPendientes.setVisibility(View.VISIBLE);
            }
        }
    }

    private void handleVisitasPendientesResponse(String response) {
        if (btnVisitasPendientes == null) {
            return;
        }
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                btnVisitasPendientes.setText("No tienes visitas pendientes de gestionar");
                btnVisitasPendientes.setVisibility(View.VISIBLE);
                return;
            }
            int pendientes = root.optInt("pendientes", 0);
            String texto = pendientes <= 0
                    ? "No tienes visitas pendientes de gestionar"
                    : "Tienes " + pendientes + " visita"
                            + (pendientes == 1 ? "" : "s")
                            + " pendientes de gestionar";
            btnVisitasPendientes.setText(texto);
            btnVisitasPendientes.setVisibility(View.VISIBLE);
        } catch (Exception e) {
            btnVisitasPendientes.setText("Visitas pendientes no disponibles");
            btnVisitasPendientes.setVisibility(View.VISIBLE);
        }
    }

    private void cargarIncidenciasPendientes() {
        if (btnIncidenciasPendientes == null) {
            return;
        }
        btnIncidenciasPendientes.setText("Cargando incidencias pendientes...");
        btnIncidenciasPendientes.setVisibility(View.VISIBLE);

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipoStr = readEquipoFromPrefs(prefs);

        try {
            String url = INCIDENCIAS_PENDIENTES_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipoStr, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            RequestQueue queue = Volley.newRequestQueue(this);
            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    this::handleIncidenciasPendientesResponse,
                    error -> {
                        if (btnIncidenciasPendientes != null) {
                            btnIncidenciasPendientes.setText("Incidencias pendientes no disponibles");
                            btnIncidenciasPendientes.setVisibility(View.VISIBLE);
                        }
                    });
            request.setShouldCache(false);
            queue.add(request);
        } catch (Exception e) {
            if (btnIncidenciasPendientes != null) {
                btnIncidenciasPendientes.setText("Incidencias pendientes no disponibles");
                btnIncidenciasPendientes.setVisibility(View.VISIBLE);
            }
        }
    }

    private void handleIncidenciasPendientesResponse(String response) {
        if (btnIncidenciasPendientes == null) {
            return;
        }
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                btnIncidenciasPendientes.setText("No tienes incidencias pendientes de gestionar");
                btnIncidenciasPendientes.setVisibility(View.VISIBLE);
                return;
            }
            int pendientes = root.optInt("pendientes", 0);
            String texto = pendientes <= 0
                    ? "No tienes incidencias pendientes de gestionar"
                    : "Tienes " + pendientes + " incidencia"
                            + (pendientes == 1 ? "" : "s")
                            + " pendientes de gestionar";
            btnIncidenciasPendientes.setText(texto);
            btnIncidenciasPendientes.setVisibility(View.VISIBLE);
        } catch (Exception e) {
            btnIncidenciasPendientes.setText("Incidencias pendientes no disponibles");
            btnIncidenciasPendientes.setVisibility(View.VISIBLE);
        }
    }

    private void abrirVisitasWeb() {
        Intent intent = new Intent(MainActivity.this, VisitasPendientesActivity.class);
        startActivity(intent);
    }

    private void abrirIncidenciasPendientes() {
        Intent intent = new Intent(MainActivity.this, IncidenciasPendientesActivity.class);
        startActivity(intent);
    }

    private void abrirGestionWeb(String referencia) {
        if (referencia == null || referencia.trim().isEmpty()) {
            Toast.makeText(this, "Referencia no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        String url = INSTALL_WEB_BASE + referencia.trim();
        Intent intent = new Intent(MainActivity.this, WebViewActivity.class);
        intent.putExtra("target_url", url);
        startActivity(intent);
    }

    private void llamarNumero(String telefono) {
        if (telefono == null || telefono.trim().isEmpty()) {
            Toast.makeText(this, "Teléfono no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(Intent.ACTION_DIAL);
        intent.setData(Uri.parse("tel:" + telefono.trim()));
        startActivity(intent);
    }

    private void abrirMapaDireccion(String direccion) {
        if (direccion == null || direccion.trim().isEmpty()) {
            Toast.makeText(this, "Dirección no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        Uri uri = Uri.parse("geo:0,0?q=" + Uri.encode(direccion.trim()));
        Intent intent = new Intent(Intent.ACTION_VIEW, uri);
        startActivity(intent);
    }

    private String resolveWhatsapp(String whatsapp, String telefono) {
        if (whatsapp != null && !whatsapp.trim().isEmpty()) {
            return whatsapp.trim();
        }
        if (telefono != null && !telefono.trim().isEmpty()) {
            return telefono.trim();
        }
        return "";
    }

    private void enviarWhatsapp(String telefono) {
        if (telefono == null || telefono.trim().isEmpty()) {
            Toast.makeText(this, "WhatsApp no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        String digits = telefono.replaceAll("[^0-9]", "");
        if (digits.isEmpty()) {
            Toast.makeText(this, "WhatsApp no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        Uri uri = Uri.parse("https://wa.me/" + digits);
        Intent intent = new Intent(Intent.ACTION_VIEW, uri);
        startActivity(intent);
    }

    private String limpiarDireccion(String rawDireccion) {
        String raw = UiText.sanitizeDbValue(rawDireccion);
        raw = raw.replace("<br/>", "\n")
                .replace("<br />", "\n")
                .replace("<br>", "\n")
                .replace("</br>", "\n")
                .replace("<BR/>", "\n")
                .replace("<BR />", "\n")
                .replace("<BR>", "\n")
                .replace("</BR>", "\n");
        raw = raw.replaceAll("<[^>]+>", "");
        // Eliminar posibles líneas de teléfono incrustadas en la dirección
        raw = raw.replaceAll("(?i)tel\\.?\\s*:?[ \\t]*\\d[\\d \\t]+", "");
        // Normalizar espacios y saltos de línea
        raw = raw.replaceAll("[ \\t]+", " ");
        raw = raw.replaceAll(" *\n *", "\n");
        return raw.trim();
    }

    private CharSequence buildDetalleDireccion(String direccion, String telefono) {
        SpannableStringBuilder builder = new SpannableStringBuilder();
        if (direccion != null && !direccion.isEmpty()) {
            appendLabelValue(builder, "Dirección", direccion);
        }
        if (telefono != null && !telefono.isEmpty()) {
            if (builder.length() > 0)
                builder.append("\n");
            appendLabelValue(builder, "Teléfono", telefono);
        }
        return builder;
    }

    private void appendLabelValue(SpannableStringBuilder builder, String label, String value) {
        int start = builder.length();
        builder.append(label).append(": ");
        builder.setSpan(new StyleSpan(android.graphics.Typeface.BOLD),
                start,
                start + label.length() + 1,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        builder.append(value);
    }

    private Bundle buildDetalleExtras(String hora,
            String referencia,
            String cliente,
            String direccion,
            String telefono,
            String whatsapp,
            String equipo,
            String estado,
            String detalles,
            String comentarios,
            String concertada,
            String emailEquipo,
            String colorHex) {
        Bundle bundle = new Bundle();
        bundle.putString("hora", hora);
        bundle.putString("pedido", referencia);
        bundle.putString("cliente", cliente);
        bundle.putString("equipoCodigo", equipo);
        bundle.putString("estado", estado);
        bundle.putString("direccion", direccion);
        bundle.putString("telefono", telefono);
        bundle.putString("whatsapp", whatsapp);
        bundle.putString("detalles", detalles);
        bundle.putString("comentarios", comentarios);
        bundle.putString("concertada", concertada);
        bundle.putString("emailEquipo", emailEquipo);
        bundle.putString("colorHex", colorHex);
        return bundle;
    }

    private void abrirDetalleInstalacion(Bundle extras, String referenciaFallback) {
        if (extras == null || !isPedidoValido(referenciaFallback)) {
            Toast.makeText(this,
                    "Este evento no tiene pedido asociado",
                    Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(MainActivity.this, PedidoDetailActivity.class);
        intent.putExtra("referencia", referenciaFallback);
        String cliente = extras.getString("cliente");
        if (cliente != null) {
            intent.putExtra("cliente", cliente);
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

    private String buildResumenDetalle(String titulo,
            Date start, Date end,
            String ref, String cliente,
            String direccion, String telefono,
            String whatsapp, String equipo, String estado,
            SimpleDateFormat dayFormat,
            SimpleDateFormat hourFormat) {
        StringBuilder sb = new StringBuilder();
        sb.append(titulo).append("\n");

        if (start != null && end != null) {
            sb.append("• Día: ").append(dayFormat.format(start)).append("\n");
            sb.append("• Hora: ")
                    .append(hourFormat.format(start))
                    .append(" - ")
                    .append(hourFormat.format(end))
                    .append("\n");
        }
        if (ref != null && !ref.trim().isEmpty()) {
            sb.append("• Referencia: ").append(ref.trim()).append("\n");
        }
        if (cliente != null && !cliente.trim().isEmpty()) {
            sb.append("• Cliente: ").append(cliente.trim()).append("\n");
        }
        if (direccion != null && !direccion.trim().isEmpty()) {
            sb.append("• Dirección: ").append(direccion.trim()).append("\n");
        }
        if (telefono != null && !telefono.trim().isEmpty()) {
            sb.append("• Teléfono: ").append(telefono.trim()).append("\n");
        }
        if (whatsapp != null && !whatsapp.trim().isEmpty()) {
            sb.append("• WhatsApp: ").append(whatsapp.trim()).append("\n");
        }
        if (equipo != null && !equipo.trim().isEmpty()) {
            sb.append("• Equipo: ").append(equipo.trim()).append("\n");
        }
        if (estado != null && !estado.trim().isEmpty()) {
            sb.append("• Estado: ").append(estado.trim()).append("\n");
        }

        return sb.toString().trim();
    }
}
