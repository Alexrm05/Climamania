package com.example.climamaniaapp;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.Log;
import android.util.Patterns;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;

import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.material.button.MaterialButton;

import org.json.JSONArray;
import org.json.JSONObject;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.NumberFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class AdicionalesPresupuestoActivity extends BaseActivity {

    private static final String TAG = "AdicionalesPresupuesto";
    private static final String API_KEY = "TEST123";
    private static final int MAX_RECOMMENDED_RESULTS = 3;
    private static final String PREFS_USAGE_KEY = "adicionales_usage_stats";
    private static final String EVENTS_URL = "https://app.clminstal.es/api/get_events.php";
    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String[] ADICIONALES_CATALOGO_URLS = new String[]{
            "https://app.clminstal.es/api/get_adicionales_catalogo.php",
            "https://app.clminstal.es/get_adicionales_catalogo.php",
            "https://clminstal.es/api/get_adicionales_catalogo.php",
            "https://clminstal.es/get_adicionales_catalogo.php"
    };
    private static final String[] GUARDAR_PRESUPUESTO_URLS = new String[]{
            "https://app.clminstal.es/api/guardar_presupuesto_instalador.php",
            "https://app.clminstal.es/api/guardar_presupuesto_instalador.php",
            "https://clminstal.es/api/guardar_presupuesto_instalador.php",
            "https://clminstal.es/api/guardar_presupuesto_instalador.php"
    };
    private static final String[] GET_PRESUPUESTOS_URLS = new String[]{
            "https://app.clminstal.es/api/get_presupuestos_instalador.php",
            "https://app.clminstal.es/get_presupuestos_instalador.php",
            "https://clminstal.es/api/get_presupuestos_instalador.php",
            "https://clminstal.es/get_presupuestos_instalador.php"
    };
    private static final int MAX_PRESUPUESTOS_RESULTS = 3;

    private static final BigDecimal ONE = new BigDecimal("1");
    private static final BigDecimal ONE_TENTH = new BigDecimal("0.1");
    private static final BigDecimal ZERO = new BigDecimal("0");
    private static final BigDecimal ONE_HUNDRED = new BigDecimal("100");

    private final Handler searchHandler = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat displayDateFormat = new SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.forLanguageTag("es-ES"));
    private final NumberFormat currencyFormat = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-ES"));
    private final List<CatalogProduct> searchResults = new ArrayList<>();
    private final Map<Integer, ProductUsage> usageStats = new HashMap<>();
    private final List<PresupuestoResumen> presupuestoResults = new ArrayList<>();
    private final LinkedHashMap<Integer, BudgetLine> lineMap = new LinkedHashMap<>();
    private boolean searchMode = false;
    private final ActivityResultLauncher<Intent> detallePresupuestoLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    result -> {
                        if (result.getResultCode() == Activity.RESULT_OK && searchMode) {
                            loadPresupuestos(true);
                        }
                    });

    private RequestQueue requestQueue;
    private Runnable pendingSearchRunnable;
    private Runnable pendingPresupuestoSearchRunnable;
    private Runnable pendingPullRefreshStopRunnable;

    private TextView txtSaludo;
    private TextView txtReferencia;
    private TextView txtCliente;
    private TextView txtDireccion;
    private TextView txtLoading;
    private TextView txtResultadosEmpty;
    private TextView txtLineasVacias;
    private TextView txtSubtotalSinIvaValue;
    private TextView txtIvaValue;
    private TextView txtTotalConIvaValue;
    private TextView txtFirmaHint;
    private TextView txtEmailWarning;
    private EditText editBuscarArticulo;
    private EditText editEmailCliente;
    private ProgressBar progressBuscar;
    private LinearLayout llResultados;
    private LinearLayout llLineas;
    private SignaturePadView signaturePad;
    private Button btnToggleSignatureInput;
    private Button btnAceptar;
    private Button btnTabNuevo;
    private Button btnTabBuscar;
    private LinearLayout layoutNuevoContainer;
    private LinearLayout layoutBuscarContainer;
    private EditText editBuscarPresupuesto;
    private ProgressBar progressBuscarPresupuestos;
    private TextView txtBuscarPresupuestosEmpty;
    private LinearLayout llBuscarPresupuestosResultados;
    private LinearLayout llBuscarEstados;
    private Button btnBuscarPresupuestosMore;

    private String referenciaActual = "";
    private String clienteActual = "";
    private String direccionActual = "";
    private String telefonoActual = "";
    private String emailClienteActual = "";
    private String referenceEmailActual = "";
    private String usuarioActual = "";
    private String instaladorNombreActual = "";
    private String equipoActual = "";
    private boolean referenceHasEmail = false;
    private boolean forceNoReferenceMode = false;
    private boolean savingPresupuesto = false;
    private String filtroEstado = "TODOS";
    private String filtroTextoPresupuesto = "";
    private int currentSearchPage = 1;
    private boolean hasMoreSearchPages = false;
    private boolean signatureInputEnabled = false;
    private EventLocationCaptureHelper locationCaptureHelper;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_adicionales_presupuesto, contentFrame, true);

        setupBottomBar();
        requestQueue = Volley.newRequestQueue(this);
        currencyFormat.setMinimumFractionDigits(2);
        currencyFormat.setMaximumFractionDigits(2);

        txtSaludo = content.findViewById(R.id.txtAdicionalesSaludo);
        txtReferencia = content.findViewById(R.id.txtAdicionalesReferencia);
        txtCliente = content.findViewById(R.id.txtAdicionalesCliente);
        txtDireccion = content.findViewById(R.id.txtAdicionalesDireccion);
        txtLoading = content.findViewById(R.id.txtAdicionalesLoading);
        txtResultadosEmpty = content.findViewById(R.id.txtAdicionalResultadosEmpty);
        txtLineasVacias = content.findViewById(R.id.txtAdicionalLineasVacias);
        txtSubtotalSinIvaValue = content.findViewById(R.id.txtSubtotalSinIvaValue);
        txtIvaValue = content.findViewById(R.id.txtIvaValue);
        txtTotalConIvaValue = content.findViewById(R.id.txtTotalConIvaValue);
        txtFirmaHint = content.findViewById(R.id.txtFirmaHint);
        txtEmailWarning = content.findViewById(R.id.txtAdicionalEmailWarning);
        editBuscarArticulo = content.findViewById(R.id.editAdicionalBuscar);
        editEmailCliente = content.findViewById(R.id.editAdicionalEmailCliente);
        progressBuscar = content.findViewById(R.id.progressAdicionalBuscar);
        llResultados = content.findViewById(R.id.llAdicionalResultados);
        llLineas = content.findViewById(R.id.llAdicionalLineas);
        signaturePad = content.findViewById(R.id.signaturePad);
        btnTabNuevo = content.findViewById(R.id.btnAdicionalTabNuevo);
        btnTabBuscar = content.findViewById(R.id.btnAdicionalTabBuscar);
        layoutNuevoContainer = content.findViewById(R.id.layoutAdicionalNuevoContainer);
        layoutBuscarContainer = content.findViewById(R.id.layoutAdicionalBuscarContainer);
        editBuscarPresupuesto = content.findViewById(R.id.editBuscarPresupuesto);
        progressBuscarPresupuestos = content.findViewById(R.id.progressBuscarPresupuestos);
        txtBuscarPresupuestosEmpty = content.findViewById(R.id.txtBuscarPresupuestosEmpty);
        llBuscarPresupuestosResultados = content.findViewById(R.id.llBuscarPresupuestosResultados);
        llBuscarEstados = content.findViewById(R.id.llBuscarEstados);
        btnBuscarPresupuestosMore = content.findViewById(R.id.btnBuscarPresupuestosMore);

        Button btnCambiarReferencia = content.findViewById(R.id.btnAdicionalCambiarReferencia);
        Button btnClearSignature = content.findViewById(R.id.btnClearSignature);
        btnToggleSignatureInput = content.findViewById(R.id.btnToggleSignatureInput);
        btnAceptar = content.findViewById(R.id.btnAdicionalAceptar);
        Button btnVolver = content.findViewById(R.id.btnAdicionalVolver);

        if (btnCambiarReferencia != null) {
            btnCambiarReferencia.setOnClickListener(v -> showManualReferenceDialog(false));
        }
        if (btnClearSignature != null) {
            btnClearSignature.setOnClickListener(v -> {
                if (signaturePad != null) {
                    signaturePad.clear();
                    updateSignatureHint();
                }
            });
        }
        if (btnToggleSignatureInput != null) {
            btnToggleSignatureInput.setOnClickListener(v -> setSignatureInputEnabled(!signatureInputEnabled));
        }
        if (btnAceptar != null) {
            btnAceptar.setEnabled(true);
            btnAceptar.setOnClickListener(v -> submitPresupuesto());
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
        if (btnTabNuevo != null) {
            btnTabNuevo.setOnClickListener(v -> switchMode(false));
        }
        if (btnTabBuscar != null) {
            btnTabBuscar.setOnClickListener(v -> switchMode(true));
        }
        if (btnBuscarPresupuestosMore != null) {
            btnBuscarPresupuestosMore.setOnClickListener(v -> {
                if (hasMoreSearchPages) {
                    loadPresupuestos(false);
                }
            });
        }
        if (signaturePad != null) {
            signaturePad.setOnTouchListener((v, event) -> {
                if (!signatureInputEnabled) {
                    setGlobalRefreshEnabled(true);
                    return false;
                }
                int action = event.getActionMasked();
                if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_MOVE) {
                    setGlobalRefreshEnabled(false);
                } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                    setGlobalRefreshEnabled(true);
                }
                boolean handled = v.onTouchEvent(event);
                updateSignatureHint();
                return handled;
            });
        }

        bindUserHeader();
        loadUsageStats();
        setupSearchInput();
        setupPresupuestoSearchInput();
        setupEmailInput();
        renderSearchResults();
        renderBudgetLines();
        updateTotals();
        setSignatureInputEnabled(false);
        updateSignatureHint();
        resolveInstallationContext();
        searchCatalog("");
        renderEstadoFilters(new JSONArray());
        switchMode(false);
        locationCaptureHelper = new EventLocationCaptureHelper(this);
    }

    @Override
    protected void onDestroy() {
        setGlobalRefreshEnabled(true);
        super.onDestroy();
        if (pendingSearchRunnable != null) {
            searchHandler.removeCallbacks(pendingSearchRunnable);
        }
        if (pendingPresupuestoSearchRunnable != null) {
            searchHandler.removeCallbacks(pendingPresupuestoSearchRunnable);
        }
        if (pendingPullRefreshStopRunnable != null) {
            searchHandler.removeCallbacks(pendingPullRefreshStopRunnable);
        }
        if (requestQueue != null) {
            requestQueue.cancelAll("adicionales");
            requestQueue.cancelAll("adicionales_save");
            requestQueue.cancelAll("adicionales_busqueda");
        }
        if (locationCaptureHelper != null) {
            locationCaptureHelper.stop();
        }
    }

    private void reloadByPullGesture() {
        if (savingPresupuesto) {
            Toast.makeText(this, "Espera a que termine el guardado", Toast.LENGTH_SHORT).show();
            stopPullRefresh();
            return;
        }
        if (requestQueue != null) {
            requestQueue.cancelAll("adicionales");
            requestQueue.cancelAll("adicionales_busqueda");
        }
        if (pendingSearchRunnable != null) {
            searchHandler.removeCallbacks(pendingSearchRunnable);
        }
        if (pendingPresupuestoSearchRunnable != null) {
            searchHandler.removeCallbacks(pendingPresupuestoSearchRunnable);
        }

        if (searchMode) {
            loadPresupuestos(true);
        } else {
            resolveInstallationContext();
            String query = "";
            if (editBuscarArticulo != null && editBuscarArticulo.getText() != null) {
                query = UiText.sanitizeDbValue(editBuscarArticulo.getText().toString());
            }
            searchCatalog(query);
        }
        schedulePullRefreshStop(1800L);
    }

    @Override
    protected void onGlobalRefreshRequested() {
        reloadByPullGesture();
    }

    private void schedulePullRefreshStop(long delayMs) {
        if (pendingPullRefreshStopRunnable != null) {
            searchHandler.removeCallbacks(pendingPullRefreshStopRunnable);
        }
        pendingPullRefreshStopRunnable = this::stopPullRefresh;
        searchHandler.postDelayed(pendingPullRefreshStopRunnable, delayMs);
    }

    private void stopPullRefresh() {
        setGlobalRefreshing(false);
        if (pendingPullRefreshStopRunnable != null) {
            searchHandler.removeCallbacks(pendingPullRefreshStopRunnable);
            pendingPullRefreshStopRunnable = null;
        }
    }

    private void bindUserHeader() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        usuarioActual = usuario;
        equipoActual = readEquipoFromPrefs(prefs);
        String displayName = !nombre.isEmpty() ? nombre : (!usuario.isEmpty() ? usuario : "instalador");
        instaladorNombreActual = displayName;
        if (txtSaludo != null) {
            txtSaludo.setText("Hola " + displayName);
        }
    }

    private void resolveInstallationContext() {
        if (forceNoReferenceMode) {
            applyNoReferenceMode(false);
            return;
        }
        showLoading("Buscando instalación en curso...");
        fetchCurrentInstallationReference(ref -> {
            if (ref == null || ref.isEmpty()) {
                referenciaActual = "";
                clienteActual = "";
                direccionActual = "";
                telefonoActual = "";
                emailClienteActual = "";
                referenceEmailActual = "";
                referenceHasEmail = false;
                if (txtReferencia != null) {
                    txtReferencia.setText("Referencia sin seleccionar");
                }
                if (txtCliente != null) {
                    txtCliente.setText("Cliente no disponible");
                }
                if (txtDireccion != null) {
                    txtDireccion.setText("Dirección no disponible");
                }
                setEmailClienteForUi("");
                hideLoading();
                return;
            }
            loadInstallationHeader(ref, false, false);
        });
    }

    private void fetchCurrentInstallationReference(ReferenceCallback callback) {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipo = readEquipoFromPrefs(prefs);

        try {
            String url = EVENTS_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipo, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> callback.onReference(resolveReferenceFromEventsResponse(response)),
                    error -> callback.onReference(""));
            request.setShouldCache(false);
            request.setTag("adicionales");
            requestQueue.add(request);
        } catch (Exception e) {
            callback.onReference("");
        }
    }

    private String resolveReferenceFromEventsResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                return "";
            }

            JSONArray eventos = root.optJSONArray("eventos");
            if (eventos == null || eventos.length() == 0) {
                return "";
            }

            Date now = new Date();
            Date bestStart = null;
            String selectedRef = "";

            for (int i = 0; i < eventos.length(); i++) {
                JSONObject ev = eventos.optJSONObject(i);
                if (ev == null) {
                    continue;
                }

                String startRaw = UiText.sanitizeDbValue(ev.optString("start", ""));
                String endRaw = UiText.sanitizeDbValue(ev.optString("end", ""));
                String referencia = UiText.sanitizeDbValue(ev.optString("referencia", ""));
                if (!isPedidoValido(referencia) || startRaw.isEmpty()) {
                    continue;
                }

                Date startDate;
                Date endDate;
                try {
                    startDate = serverDateFormat.parse(startRaw);
                    if (startDate == null) {
                        continue;
                    }
                    if (!endRaw.isEmpty()) {
                        endDate = serverDateFormat.parse(endRaw);
                    } else {
                        endDate = new Date(startDate.getTime() + 60L * 60L * 1000L);
                    }
                    if (endDate == null) {
                        endDate = new Date(startDate.getTime() + 60L * 60L * 1000L);
                    }
                } catch (ParseException ignored) {
                    continue;
                }

                boolean enCurso = !now.before(startDate) && now.before(endDate);
                if (!enCurso) {
                    continue;
                }

                if (bestStart == null || startDate.before(bestStart)) {
                    bestStart = startDate;
                    selectedRef = referencia;
                }
            }

            return selectedRef;
        } catch (Exception e) {
            return "";
        }
    }

    private void applyNoReferenceMode(boolean showToast) {
        forceNoReferenceMode = true;
        referenciaActual = "";
        clienteActual = "";
        direccionActual = "";
        telefonoActual = "";
        emailClienteActual = "";
        referenceEmailActual = "";
        referenceHasEmail = false;
        if (txtReferencia != null) {
            txtReferencia.setText("Sin referencia (manual)");
        }
        if (txtCliente != null) {
            txtCliente.setText("Cliente no disponible");
        }
        if (txtDireccion != null) {
            txtDireccion.setText("Dirección no disponible");
        }
        setEmailClienteForUi("");
        hideLoading();
        if (showToast) {
            Toast.makeText(this, "Modo sin referencia activado", Toast.LENGTH_SHORT).show();
        }
    }

    private void showManualReferenceDialog(boolean finishOnCancel) {
        final EditText input = new EditText(this);
        input.setHint("Referencia de instalación");
        input.setSingleLine(true);
        int padding = dp(12);
        input.setPadding(padding, padding, padding, padding);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("Seleccionar instalación")
                .setMessage("Introduce la referencia de la instalación o deja el campo vacío para crear un presupuesto sin referencia.")
                .setView(input)
                .setPositiveButton("Cargar", null)
                .setNeutralButton("Sin referencia", (d, which) -> applyNoReferenceMode(true))
                .setNegativeButton("Cancelar", (d, which) -> {
                    if (finishOnCancel) {
                        finish();
                    }
                })
                .create();

        dialog.setOnShowListener(d -> {
            Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
            if (positive != null) {
                positive.setOnClickListener(v -> {
                    String ref = UiText.sanitizeDbValue(input.getText() != null ? input.getText().toString() : "");
                    if (ref.isEmpty()) {
                        dialog.dismiss();
                        applyNoReferenceMode(true);
                        return;
                    }
                    if (!isPedidoValido(ref) || isManualPedido(ref)) {
                        Toast.makeText(this, "Referencia no válida", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    dialog.dismiss();
                    forceNoReferenceMode = false;
                    loadInstallationHeader(ref, true, finishOnCancel);
                });
            }
        });
        dialog.show();
    }

    private void loadInstallationHeader(String referencia, boolean fromManual, boolean allowManualFallback) {
        showLoading("Cargando datos de la instalación...");

        try {
            String url = PEDIDO_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&referencia=" + URLEncoder.encode(referencia, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> handlePedidoResponse(response, referencia, fromManual, allowManualFallback),
                    error -> {
                        showLoading("No se pudo cargar la instalación");
                        if (allowManualFallback) {
                            showManualReferenceDialog(true);
                        }
                    });
            request.setShouldCache(false);
            request.setTag("adicionales");
            requestQueue.add(request);
        } catch (Exception e) {
            showLoading("No se pudo cargar la instalación");
            if (allowManualFallback) {
                showManualReferenceDialog(true);
            }
        }
    }

    private void handlePedidoResponse(String response, String referencia, boolean fromManual, boolean allowManualFallback) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String msg = UiText.sanitizeDbValue(root.optString("message", "No se encontró la instalación"));
                Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
                if (fromManual || allowManualFallback) {
                    showManualReferenceDialog(true);
                }
                return;
            }

            JSONObject pedido = root.optJSONObject("pedido");
            if (pedido == null) {
                Toast.makeText(this, "Datos de instalación no disponibles", Toast.LENGTH_SHORT).show();
                if (fromManual || allowManualFallback) {
                    showManualReferenceDialog(true);
                }
                return;
            }

            referenciaActual = referencia;
            forceNoReferenceMode = false;
            clienteActual = UiText.sanitizeDbValue(pedido.optString("cliente", ""));
            direccionActual = UiText.sanitizeDbValue(pedido.optString("direccion_instalacion", ""));
            telefonoActual = "";
            referenceEmailActual = UiText.sanitizeDbValue(pedido.optString("email_cliente", ""));
            referenceHasEmail = isValidEmail(referenceEmailActual);
            emailClienteActual = referenceHasEmail ? referenceEmailActual : "";

            JSONObject entrega = pedido.optJSONObject("entrega");
            if (entrega != null) {
                String telEntrega = UiText.sanitizeDbValue(entrega.optString("telefono", ""));
                if (!telEntrega.isEmpty()) {
                    telefonoActual = telEntrega;
                }
            }

            JSONObject facturacion = pedido.optJSONObject("facturacion");
            if (facturacion != null) {
                if (telefonoActual.isEmpty()) {
                    telefonoActual = UiText.sanitizeDbValue(facturacion.optString("telefono", ""));
                }
            }

            if (txtReferencia != null) {
                txtReferencia.setText("Referencia " + referenciaActual);
            }
            if (txtCliente != null) {
                UiText.setTextOrPlaceholder(txtCliente, clienteActual, "Cliente no disponible");
            }
            if (txtDireccion != null) {
                UiText.setTextOrPlaceholder(txtDireccion, direccionActual, "Dirección no disponible");
            }
            setEmailClienteForUi(emailClienteActual);
            hideLoading();

            if (fromManual) {
                Toast.makeText(this, "Instalación cargada", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            Toast.makeText(this, "Respuesta inválida al cargar instalación", Toast.LENGTH_SHORT).show();
            if (fromManual || allowManualFallback) {
                showManualReferenceDialog(true);
            }
        }
    }

    private void setupSearchInput() {
        if (editBuscarArticulo == null) {
            return;
        }

        editBuscarArticulo.addTextChangedListener(new SimpleTextWatcher() {
            @Override
            public void afterTextChanged(Editable s) {
                String query = UiText.sanitizeDbValue(s != null ? s.toString() : "");
                if (pendingSearchRunnable != null) {
                    searchHandler.removeCallbacks(pendingSearchRunnable);
                }
                pendingSearchRunnable = () -> searchCatalog(query);
                searchHandler.postDelayed(pendingSearchRunnable, 300L);
            }
        });
    }

    private void setupPresupuestoSearchInput() {
        if (editBuscarPresupuesto == null) {
            return;
        }

        editBuscarPresupuesto.addTextChangedListener(new SimpleTextWatcher() {
            @Override
            public void afterTextChanged(Editable s) {
                filtroTextoPresupuesto = UiText.sanitizeDbValue(s != null ? s.toString() : "");
                if (!searchMode) {
                    return;
                }
                if (pendingPresupuestoSearchRunnable != null) {
                    searchHandler.removeCallbacks(pendingPresupuestoSearchRunnable);
                }
                pendingPresupuestoSearchRunnable = () -> loadPresupuestos(true);
                searchHandler.postDelayed(pendingPresupuestoSearchRunnable, 300L);
            }
        });
    }

    private void setupEmailInput() {
        if (editEmailCliente == null) {
            return;
        }
        applyEmailFieldMode();
        editEmailCliente.addTextChangedListener(new SimpleTextWatcher() {
            @Override
            public void afterTextChanged(Editable s) {
                emailClienteActual = UiText.sanitizeDbValue(s != null ? s.toString() : "");
            }
        });
    }

    private void switchMode(boolean buscarMode) {
        searchMode = buscarMode;
        if (layoutNuevoContainer != null) {
            layoutNuevoContainer.setVisibility(searchMode ? View.GONE : View.VISIBLE);
        }
        if (layoutBuscarContainer != null) {
            layoutBuscarContainer.setVisibility(searchMode ? View.VISIBLE : View.GONE);
        }
        refreshTabStyles();

        if (searchMode) {
            loadPresupuestos(true);
        }
    }

    private void refreshTabStyles() {
        styleTabButton(btnTabNuevo, !searchMode);
        styleTabButton(btnTabBuscar, searchMode);
    }

    private void styleTabButton(@Nullable Button btn, boolean active) {
        if (btn == null) {
            return;
        }
        int textColor = ContextCompat.getColor(this, active ? R.color.colorPrimaryDark : R.color.footerInactive);
        int bgColor = active ? 0xFFFFF6E8 : 0xFFFFFFFF;
        int strokeColor = active ? 0xFFCF995B : 0xFFCAD4DE;
        btn.setTextColor(textColor);
        if (btn instanceof com.google.android.material.button.MaterialButton) {
            com.google.android.material.button.MaterialButton mb = (com.google.android.material.button.MaterialButton) btn;
            mb.setBackgroundTintList(ColorStateList.valueOf(bgColor));
            mb.setStrokeColor(ColorStateList.valueOf(strokeColor));
        }
    }

    private void loadPresupuestos(boolean resetPage) {
        if (!searchMode) {
            return;
        }
        int targetPage = resetPage ? 1 : (currentSearchPage + 1);
        if (progressBuscarPresupuestos != null) {
            progressBuscarPresupuestos.setVisibility(View.VISIBLE);
        }
        loadPresupuestosWithFallback(resetPage, targetPage, 0, "");
    }

    private void loadPresupuestosWithFallback(boolean resetPage, int targetPage, int index, String lastError) {
        if (index >= GET_PRESUPUESTOS_URLS.length) {
            if (progressBuscarPresupuestos != null) {
                progressBuscarPresupuestos.setVisibility(View.GONE);
            }
            stopPullRefresh();
            if (txtBuscarPresupuestosEmpty != null) {
                txtBuscarPresupuestosEmpty.setVisibility(View.VISIBLE);
                String msg = UiText.sanitizeDbValue(lastError);
                if (msg.isEmpty()) {
                    msg = "No se pudo cargar la búsqueda";
                }
                txtBuscarPresupuestosEmpty.setText(msg);
            }
            return;
        }

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipo = readEquipoFromPrefs(prefs);

        try {
            String baseUrl = GET_PRESUPUESTOS_URLS[index];
            String url = baseUrl
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipo, "UTF-8")
                    + "&q=" + URLEncoder.encode(filtroTextoPresupuesto, "UTF-8")
                    + "&estado=" + URLEncoder.encode(filtroEstado, "UTF-8")
                    + "&page=" + targetPage
                    + "&page_size=" + MAX_PRESUPUESTOS_RESULTS
                    + "&_ts=" + System.currentTimeMillis();

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> {
                        String parseError = parsePresupuestosResponse(response, endpointLabel(baseUrl), resetPage, targetPage);
                        if (parseError == null) {
                            if (progressBuscarPresupuestos != null) {
                                progressBuscarPresupuestos.setVisibility(View.GONE);
                            }
                            stopPullRefresh();
                            return;
                        }
                        loadPresupuestosWithFallback(resetPage, targetPage, index + 1, parseError);
                    },
                    error -> {
                        String errorMessage = buildVolleyErrorMessage(error, "No se pudo cargar la búsqueda");
                        loadPresupuestosWithFallback(resetPage, targetPage, index + 1, errorMessage);
                    });
            request.setShouldCache(false);
            request.setTag("adicionales_busqueda");
            requestQueue.add(request);
        } catch (Exception e) {
            loadPresupuestosWithFallback(resetPage, targetPage, index + 1, "No se pudo cargar la búsqueda");
        }
    }

    @Nullable
    private String parsePresupuestosResponse(String response, String sourceLabel, boolean resetPage, int requestedPage) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = getJsonMessage(root, "No se pudo cargar la búsqueda");
                Log.w(TAG, "Buscar presupuestos success=false en " + sourceLabel + ": " + message);
                return message;
            }

            if (resetPage) {
                presupuestoResults.clear();
                renderEstadoFilters(root.optJSONArray("estados_disponibles"));
            }

            JSONArray items = root.optJSONArray("presupuestos");
            if (items != null) {
                for (int i = 0; i < items.length(); i++) {
                    if (presupuestoResults.size() >= MAX_PRESUPUESTOS_RESULTS) {
                        break;
                    }
                    JSONObject item = items.optJSONObject(i);
                    if (item == null) {
                        continue;
                    }
                    PresupuestoResumen resumen = parsePresupuestoResumen(item);
                    if (resumen != null) {
                        presupuestoResults.add(resumen);
                    }
                }
            }

            currentSearchPage = root.optInt("page", requestedPage);
            hasMoreSearchPages = false;
            renderPresupuestoResults();
            return null;
        } catch (Exception e) {
            String error = "Respuesta inválida de búsqueda";
            Log.w(TAG, error + " en " + sourceLabel, e);
            return error;
        }
    }

    @Nullable
    private PresupuestoResumen parsePresupuestoResumen(JSONObject item) {
        int id = item.optInt("id_presupuesto", 0);
        if (id <= 0) {
            return null;
        }
        PresupuestoResumen resumen = new PresupuestoResumen();
        resumen.idPresupuesto = id;
        resumen.numeroPedido = UiText.sanitizeDbValue(item.optString("numero_pedido", ""));
        resumen.nombreCliente = UiText.sanitizeDbValue(item.optString("nombre_cliente", ""));
        resumen.telefono = UiText.sanitizeDbValue(item.optString("telefono", ""));
        resumen.equipo = UiText.sanitizeDbValue(item.optString("equipo_instaladores", ""));
        resumen.usuario = UiText.sanitizeDbValue(item.optString("usuario_instalador", ""));
        resumen.importeConIva = UiText.sanitizeDbValue(item.optString("importe_con_iva", "0"));
        resumen.estado = UiText.sanitizeDbValue(item.optString("estado", ""));
        resumen.fechaPresupuesto = UiText.sanitizeDbValue(item.optString("fecha_presupuesto", ""));
        resumen.mailEnviado = item.optBoolean("mail_enviado", false);
        return resumen;
    }

    private void renderEstadoFilters(@Nullable JSONArray estadosJson) {
        if (llBuscarEstados == null) {
            return;
        }
        List<String> estados = new ArrayList<>();
        estados.add("TODOS");
        if (estadosJson != null) {
            for (int i = 0; i < estadosJson.length(); i++) {
                String st = UiText.sanitizeDbValue(estadosJson.optString(i, "")).toUpperCase(Locale.ROOT);
                if (!st.isEmpty() && !estados.contains(st)) {
                    estados.add(st);
                }
            }
        }
        if (!estados.contains(filtroEstado)) {
            filtroEstado = "TODOS";
        }

        llBuscarEstados.removeAllViews();
        for (String estado : estados) {
            com.google.android.material.button.MaterialButton chip =
                    new com.google.android.material.button.MaterialButton(this);
            chip.setText("TODOS".equals(estado) ? "Todos" : estado);
            chip.setTag(estado);
            chip.setAllCaps(false);
            chip.setMinHeight(dp(36));
            chip.setMinimumHeight(dp(36));
            chip.setCornerRadius(dp(18));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT);
            lp.setMarginEnd(dp(8));
            chip.setLayoutParams(lp);
            chip.setOnClickListener(v -> {
                String selected = String.valueOf(v.getTag());
                filtroEstado = UiText.sanitizeDbValue(selected).toUpperCase(Locale.ROOT);
                refreshEstadoFilterStyles();
                loadPresupuestos(true);
            });
            llBuscarEstados.addView(chip);
        }
        refreshEstadoFilterStyles();
    }

    private void refreshEstadoFilterStyles() {
        if (llBuscarEstados == null) {
            return;
        }
        int activeText = ContextCompat.getColor(this, R.color.colorPrimaryDark);
        int inactiveText = ContextCompat.getColor(this, R.color.footerInactive);
        for (int i = 0; i < llBuscarEstados.getChildCount(); i++) {
            View child = llBuscarEstados.getChildAt(i);
            if (!(child instanceof com.google.android.material.button.MaterialButton)) {
                continue;
            }
            com.google.android.material.button.MaterialButton chip =
                    (com.google.android.material.button.MaterialButton) child;
            String state = UiText.sanitizeDbValue(String.valueOf(chip.getTag())).toUpperCase(Locale.ROOT);
            boolean active = filtroEstado.equals(state);
            chip.setTextColor(active ? activeText : inactiveText);
            chip.setBackgroundTintList(ColorStateList.valueOf(active ? 0xFFFFF6E8 : 0xFFFFFFFF));
            chip.setStrokeColor(ColorStateList.valueOf(active ? 0xFFCF995B : 0xFFCAD4DE));
        }
    }

    private void renderPresupuestoResults() {
        if (llBuscarPresupuestosResultados == null) {
            return;
        }
        llBuscarPresupuestosResultados.removeAllViews();

        if (presupuestoResults.isEmpty()) {
            if (txtBuscarPresupuestosEmpty != null) {
                txtBuscarPresupuestosEmpty.setVisibility(View.VISIBLE);
                txtBuscarPresupuestosEmpty.setText("Sin resultados para esta búsqueda");
            }
        } else {
            if (txtBuscarPresupuestosEmpty != null) {
                txtBuscarPresupuestosEmpty.setVisibility(View.GONE);
            }
        }

        for (PresupuestoResumen item : presupuestoResults) {
            View row = getLayoutInflater().inflate(R.layout.item_presupuesto_busqueda, llBuscarPresupuestosResultados, false);
            TextView txtIdPedido = row.findViewById(R.id.txtBusPresIdPedido);
            TextView txtEstado = row.findViewById(R.id.txtBusPresEstado);
            TextView txtCliente = row.findViewById(R.id.txtBusPresCliente);
            TextView txtMeta = row.findViewById(R.id.txtBusPresMeta);
            TextView txtImporte = row.findViewById(R.id.txtBusPresImporte);
            String pedido = item.numeroPedido.isEmpty() ? "-" : item.numeroPedido;
            String cliente = item.nombreCliente.isEmpty() ? "Cliente no disponible" : item.nombreCliente;
            String estado = item.estado.isEmpty() ? "N/D" : item.estado;
            String fecha = formatFechaListado(item.fechaPresupuesto);
            String tel = item.telefono.isEmpty() ? "Sin teléfono" : item.telefono;
            String equipo = item.equipo.isEmpty() ? "Sin equipo" : ("Eq. " + item.equipo);
            String usuario = item.usuario.isEmpty() ? "Sin usuario" : item.usuario;
            String importe = item.importeConIva.isEmpty() ? "0,00" : item.importeConIva;

            txtIdPedido.setText("#" + item.idPresupuesto + " · Pedido " + pedido);
            txtEstado.setText(estado.toUpperCase(Locale.ROOT));
            txtCliente.setText(cliente);
            txtMeta.setText(tel + " · " + equipo + " · " + usuario + " · " + fecha);
            txtImporte.setText("Total: " + importe + " €" + (item.mailEnviado ? " · Mail OK" : " · Mail pendiente"));
            applyPresupuestoEstadoStyle(txtEstado, estado);

            row.setOnClickListener(v -> openPresupuestoDetalle(item));
            llBuscarPresupuestosResultados.addView(row);
        }

        if (btnBuscarPresupuestosMore != null) {
            btnBuscarPresupuestosMore.setVisibility(hasMoreSearchPages ? View.VISIBLE : View.GONE);
        }
    }

    private void applyPresupuestoEstadoStyle(TextView view, String estadoRaw) {
        if (view == null) {
            return;
        }
        String estado = UiText.sanitizeDbValue(estadoRaw).toUpperCase(Locale.ROOT);
        if ("CANCELADO".equals(estado)) {
            view.setTextColor(Color.parseColor("#9A3412"));
            view.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#FFF1EB")));
            return;
        }
        view.setTextColor(Color.parseColor("#345C38"));
        view.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#FFF6E8")));
    }

    private void openPresupuestoDetalle(PresupuestoResumen item) {
        Intent intent = new Intent(this, PresupuestoInstaladorDetalleActivity.class);
        intent.putExtra("id_presupuesto", String.valueOf(item.idPresupuesto));
        detallePresupuestoLauncher.launch(intent);
    }

    private String formatFechaListado(String rawDate) {
        String raw = UiText.sanitizeDbValue(rawDate);
        if (raw.isEmpty()) {
            return "Sin fecha";
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

    private void submitPresupuesto() {
        if (savingPresupuesto) {
            return;
        }
        if (lineMap.isEmpty()) {
            Toast.makeText(this, "Añade al menos una línea al presupuesto", Toast.LENGTH_SHORT).show();
            return;
        }
        if (!ensureEmailForSave()) {
            return;
        }
        if (signaturePad == null || !signaturePad.hasSignature()) {
            Toast.makeText(this, "La firma del cliente es obligatoria", Toast.LENGTH_SHORT).show();
            return;
        }

        String firmaBase64;
        try {
            firmaBase64 = signaturePad.exportToBase64Png();
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo capturar la firma", Toast.LENGTH_SHORT).show();
            return;
        }

        JSONArray lineasJson = buildLineasPayload();
        if (lineasJson.length() == 0) {
            Toast.makeText(this, "No hay líneas válidas para guardar", Toast.LENGTH_SHORT).show();
            return;
        }

        setSavingPresupuesto(true, "Obteniendo ubicación...");
        locationCaptureHelper.capture(new EventLocationCaptureHelper.Callback() {
            @Override
            public void onLocationReady(@androidx.annotation.NonNull EventLocationCaptureHelper.CapturedLocation location) {
                Map<String, String> payload = buildPresupuestoPayload(firmaBase64, lineasJson, location);
                setSavingPresupuesto(true);
                savePresupuestoWithFallback(payload, 0, "");
            }

            @Override
            public void onLocationError(@androidx.annotation.NonNull String message) {
                setSavingPresupuesto(false);
                Toast.makeText(AdicionalesPresupuestoActivity.this, message, Toast.LENGTH_LONG).show();
            }
        });
    }

    private JSONArray buildLineasPayload() {
        JSONArray arr = new JSONArray();
        int orden = 1;
        for (BudgetLine line : lineMap.values()) {
            try {
                JSONObject obj = new JSONObject();
                obj.put("orden", orden);
                obj.put("cantidad", formatApiDecimal(line.quantity, 2));
                obj.put("articulo", line.product.codigo.isEmpty() ? "SIN-CODIGO" : line.product.codigo);
                String desc = UiText.sanitizeDbValue(line.description);
                if (desc.isEmpty()) {
                    desc = line.product.descripcion;
                }
                obj.put("descripcion", desc);
                obj.put("precio_unitario_sin_iva", formatApiDecimal(line.unitSinIva, 6));
                obj.put("precio_total_linea_sin_iva", formatApiDecimal(line.totalSinIva, 2));
                obj.put("iva_pct", formatApiDecimal(line.product.ivaPct, 3));
                obj.put("precio_total_linea_con_iva", formatApiDecimal(line.totalConIva, 2));
                obj.put("iva_fallback", line.product.ivaFallback);
                arr.put(obj);
                orden++;
            } catch (Exception ignored) {
                // Ignorar linea corrupta y continuar con el resto.
            }
        }
        return arr;
    }

    private Map<String, String> buildPresupuestoPayload(
            String firmaBase64,
            JSONArray lineasJson,
            EventLocationCaptureHelper.CapturedLocation location
    ) {
        Totals totals = calculateTotals();
        String numeroPedido = resolveNumeroPedidoForSave();
        String referenciaPayload = hasReferenceForBudget() ? UiText.sanitizeDbValue(referenciaActual) : "";
        String nombreCliente = normalizeClientField(clienteActual, "Cliente");
        String direccionCliente = normalizeClientField(direccionActual, "");
        String telefonoCliente = normalizeClientField(telefonoActual, "");
        String emailCliente = resolveEmailClienteForSave();
        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("referencia", referenciaPayload);
        params.put("numero_pedido", numeroPedido);
        params.put("nombre_cliente", nombreCliente);
        params.put("direccion_cliente", direccionCliente);
        params.put("telefono", telefonoCliente);
        params.put("email_cliente", emailCliente);
        params.put("usuario_instalador",
                !instaladorNombreActual.isEmpty() ? instaladorNombreActual : usuarioActual);
        params.put("equipo_instaladores", equipoActual);
        params.put("total_sin_iva", formatApiDecimal(totals.sinIva, 2));
        params.put("total_iva", formatApiDecimal(totals.iva, 2));
        params.put("total_con_iva", formatApiDecimal(totals.conIva, 2));
        params.put("firma_base64", firmaBase64);
        params.put("lineas_json", lineasJson.toString());
        params.put("latitud", location.latitudeParam());
        params.put("longitud", location.longitudeParam());
        return params;
    }

    private String resolveNumeroPedidoForSave() {
        String ref = UiText.sanitizeDbValue(referenciaActual);
        if (hasReferenceForBudget()) {
            return ref;
        }
        return "MANUAL-" + System.currentTimeMillis();
    }

    private String normalizeClientField(String raw, String fallback) {
        String value = UiText.sanitizeDbValue(raw);
        String lower = value.toLowerCase(Locale.ROOT);
        if (value.isEmpty()
                || lower.contains("no disponible")
                || lower.contains("sin seleccionar")) {
            return UiText.sanitizeDbValue(fallback);
        }
        return value;
    }

    private String resolveEmailClienteForSave() {
        if (hasReferenceForBudget() && referenceHasEmail) {
            return UiText.sanitizeDbValue(referenceEmailActual);
        }
        String email = "";
        if (editEmailCliente != null && editEmailCliente.getText() != null) {
            email = UiText.sanitizeDbValue(editEmailCliente.getText().toString());
        }
        if (email.isEmpty()) {
            email = normalizeClientField(emailClienteActual, "");
        }
        return email;
    }

    private boolean ensureEmailForSave() {
        String email = resolveEmailClienteForSave();
        boolean referenciaValida = hasReferenceForBudget();
        if (referenciaValida && referenceHasEmail) {
            if (!isValidEmail(email)) {
                Toast.makeText(this, "Email de referencia no válido", Toast.LENGTH_SHORT).show();
                return false;
            }
            return true;
        }

        if (!referenciaValida) {
            if (!isValidEmail(email)) {
                showEmailRequiredDialog();
                return false;
            }
            return true;
        }

        if (!isValidEmail(email)) {
            Toast.makeText(this, "Esta referencia no tiene email. Introduce uno válido para este envío", Toast.LENGTH_SHORT).show();
            if (editEmailCliente != null) {
                editEmailCliente.requestFocus();
            }
            return false;
        }
        return true;
    }

    private void showEmailRequiredDialog() {
        final EditText input = new EditText(this);
        input.setHint("cliente@dominio.com");
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        int padding = dp(12);
        input.setPadding(padding, padding, padding, padding);
        String current = resolveEmailClienteForSave();
        if (!current.isEmpty()) {
            input.setText(current);
            input.setSelection(current.length());
        }

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("Email del cliente")
                .setMessage("Sin referencia asignada debes indicar un email para continuar.")
                .setView(input)
                .setPositiveButton("Continuar", null)
                .setNegativeButton("Cancelar", null)
                .create();

        dialog.setOnShowListener(d -> {
            Button positive = dialog.getButton(AlertDialog.BUTTON_POSITIVE);
            if (positive != null) {
                positive.setOnClickListener(v -> {
                    String email = UiText.sanitizeDbValue(input.getText() != null ? input.getText().toString() : "");
                    if (!isValidEmail(email)) {
                        Toast.makeText(this, "Introduce un email válido", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    setEmailClienteForUi(email);
                    dialog.dismiss();
                    submitPresupuesto();
                });
            }
        });
        dialog.show();
    }

    private void setEmailClienteForUi(String email) {
        String safeEmail = UiText.sanitizeDbValue(email);
        emailClienteActual = safeEmail;
        if (editEmailCliente != null) {
            String current = editEmailCliente.getText() != null
                    ? UiText.sanitizeDbValue(editEmailCliente.getText().toString())
                    : "";
            if (!safeEmail.equals(current)) {
                editEmailCliente.setText(safeEmail);
                editEmailCliente.setSelection(safeEmail.length());
            }
        }
        applyEmailFieldMode();
    }

    private void applyEmailFieldMode() {
        if (editEmailCliente == null) {
            return;
        }
        boolean withReference = hasReferenceForBudget();
        if (withReference && referenceHasEmail) {
            editEmailCliente.setHint("Email de la referencia");
            setEmailFieldEditable(false);
            if (txtEmailWarning != null) {
                txtEmailWarning.setVisibility(View.GONE);
            }
            return;
        }

        setEmailFieldEditable(true);
        if (withReference) {
            editEmailCliente.setHint("Email cliente (solo para este envío)");
            if (txtEmailWarning != null) {
                txtEmailWarning.setVisibility(View.VISIBLE);
            }
        } else {
            editEmailCliente.setHint("Email cliente (obligatorio sin referencia)");
            if (txtEmailWarning != null) {
                txtEmailWarning.setVisibility(View.GONE);
            }
        }
    }

    private void setEmailFieldEditable(boolean editable) {
        if (editEmailCliente == null) {
            return;
        }
        editEmailCliente.setEnabled(editable);
        editEmailCliente.setFocusable(editable);
        editEmailCliente.setFocusableInTouchMode(editable);
        editEmailCliente.setClickable(editable);
        editEmailCliente.setLongClickable(editable);
        editEmailCliente.setCursorVisible(editable);
    }

    private boolean hasReferenceForBudget() {
        String ref = UiText.sanitizeDbValue(referenciaActual);
        return isPedidoValido(ref) && !isManualPedido(ref);
    }

    private boolean isValidEmail(String email) {
        String clean = UiText.sanitizeDbValue(email);
        return !clean.isEmpty() && Patterns.EMAIL_ADDRESS.matcher(clean).matches();
    }

    private void savePresupuestoWithFallback(Map<String, String> payload, int index, String lastError) {
        if (index >= GUARDAR_PRESUPUESTO_URLS.length) {
            setSavingPresupuesto(false);
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo guardar el presupuesto";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            Log.w(TAG, "Guardar presupuesto sin endpoint disponible. " + msg);
            return;
        }

        String baseUrl = GUARDAR_PRESUPUESTO_URLS[index];
        StringRequest request = new StringRequest(
                Request.Method.POST,
                baseUrl,
                response -> {
                    String parseError = parseSavePresupuestoResponse(response, endpointLabel(baseUrl));
                    if (parseError == null) {
                        return;
                    }
                    savePresupuestoWithFallback(payload, index + 1, parseError);
                },
                error -> {
                    String errorMessage = buildVolleyErrorMessage(error, "No se pudo guardar el presupuesto");
                    Log.w(TAG, "Error guardando presupuesto en [" + index + "] " + baseUrl + ": " + errorMessage);
                    savePresupuestoWithFallback(payload, index + 1, errorMessage);
                }) {
            @Override
            protected Map<String, String> getParams() {
                return payload;
            }
        };
        request.setShouldCache(false);
        request.setTag("adicionales_save");
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        requestQueue.add(request);
        Log.d(TAG, "Guardando presupuesto en [" + index + "] " + baseUrl);
    }

    @Nullable
    private String parseSavePresupuestoResponse(String response, String sourceLabel) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = getJsonMessage(root, "No se pudo guardar el presupuesto");
                Log.w(TAG, "Guardar presupuesto success=false en " + sourceLabel + ": " + message);
                return message;
            }

            setSavingPresupuesto(false);
            String message = getJsonMessage(root, "Presupuesto guardado");
            int idPresupuesto = root.optInt("id_presupuesto", 0);
            if (idPresupuesto > 0) {
                message = message + " (ID " + idPresupuesto + ")";
            }
            Toast.makeText(this, message, Toast.LENGTH_LONG).show();
            setResult(RESULT_OK);
            finish();
            return null;
        } catch (Exception e) {
            String message = "Respuesta inválida del servidor";
            Log.w(TAG, message + " en " + sourceLabel, e);
            return message;
        }
    }

    private void setSavingPresupuesto(boolean saving) {
        setSavingPresupuesto(saving, saving ? "Guardando..." : "Aceptar");
    }

    private void setSavingPresupuesto(boolean saving, String buttonText) {
        savingPresupuesto = saving;
        if (btnAceptar != null) {
            btnAceptar.setEnabled(!saving);
            btnAceptar.setText(buttonText);
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

    private void searchCatalog(String query) {
        if (progressBuscar != null) {
            progressBuscar.setVisibility(View.VISIBLE);
        }
        searchCatalogWithFallback(query, 0, "");
    }

    private void searchCatalogWithFallback(String query, int index, String lastError) {
        if (index >= ADICIONALES_CATALOGO_URLS.length) {
            if (progressBuscar != null) {
                progressBuscar.setVisibility(View.GONE);
            }
            stopPullRefresh();
            clearSearchResults(true);
            if (txtResultadosEmpty != null) {
                String message = UiText.sanitizeDbValue(lastError);
                if (message.isEmpty()) {
                    message = "No se pudo cargar el catálogo";
                }
                txtResultadosEmpty.setText(message);
            }
            Log.w(TAG, "Catálogo no disponible en ninguna URL. " + UiText.sanitizeDbValue(lastError));
            return;
        }

        try {
            String baseUrl = ADICIONALES_CATALOGO_URLS[index];
            String url = baseUrl
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&q=" + URLEncoder.encode(query, "UTF-8")
                    + "&limit=0"
                    + "&_ts=" + System.currentTimeMillis();
            Log.d(TAG, "Buscando adicionales en [" + index + "] " + baseUrl + " q=" + query);

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> {
                        String parseError = parseCatalogResponse(response, endpointLabel(baseUrl));
                        if (parseError == null) {
                            if (progressBuscar != null) {
                                progressBuscar.setVisibility(View.GONE);
                            }
                            stopPullRefresh();
                            return;
                        }
                        searchCatalogWithFallback(query, index + 1, parseError);
                    },
                    error -> {
                        String errorMessage = "No se pudo cargar el catálogo";
                        if (error.networkResponse != null) {
                            errorMessage = "Error HTTP " + error.networkResponse.statusCode;
                        } else if (error.getMessage() != null && !error.getMessage().trim().isEmpty()) {
                            errorMessage = error.getMessage().trim();
                        }
                        Log.w(TAG, "Error catálogo en [" + index + "] " + baseUrl + ": " + errorMessage);
                        searchCatalogWithFallback(query, index + 1, errorMessage);
                    });
            request.setShouldCache(false);
            request.setTag("adicionales");
            requestQueue.add(request);
        } catch (Exception e) {
            searchCatalogWithFallback(query, index + 1, "No se pudo cargar el catálogo");
        }
    }

    @Nullable
    private String parseCatalogResponse(String response, String sourceLabel) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                clearSearchResults(true);
                if (txtResultadosEmpty != null) {
                    txtResultadosEmpty.setText("Catálogo no disponible");
                }
                String backendMessage = UiText.sanitizeDbValue(root.optString("message", ""));
                if (backendMessage.isEmpty()) {
                    backendMessage = "Catálogo no disponible";
                }
                Log.w(TAG, "Catálogo success=false desde " + sourceLabel + ": " + backendMessage);
                return backendMessage;
            }

            JSONArray productos = root.optJSONArray("productos");
            searchResults.clear();

            if (productos != null) {
                for (int i = 0; i < productos.length(); i++) {
                    JSONObject item = productos.optJSONObject(i);
                    if (item == null) {
                        continue;
                    }
                    CatalogProduct product = parseCatalogProduct(item);
                    if (product != null) {
                        searchResults.add(product);
                    }
                }
            }

            renderSearchResults();
            Log.d(TAG, "Catálogo cargado desde " + sourceLabel + ". resultados=" + searchResults.size());
            return null;
        } catch (Exception e) {
            String error = "Respuesta inválida del catálogo";
            Log.w(TAG, error + " en " + sourceLabel, e);
            return error;
        }
    }

    private String endpointLabel(String url) {
        String clean = UiText.sanitizeDbValue(url);
        if (clean.isEmpty()) {
            return "endpoint desconocido";
        }
        return clean.replace("https://", "");
    }

    @Nullable
    private CatalogProduct parseCatalogProduct(JSONObject item) {
        int idProduct = item.optInt("id_product", 0);
        if (idProduct <= 0) {
            return null;
        }

        String codigo = UiText.sanitizeDbValue(item.optString("codigo", ""));
        String descripcion = UiText.sanitizeDbValue(item.optString("descripcion", ""));
        if (descripcion.isEmpty()) {
            descripcion = "Descripción no disponible";
        }

        BigDecimal precioBase = parseBigDecimal(item, "precio_base_sin_iva", ZERO);
        BigDecimal ivaPct = parseBigDecimal(item, "iva_pct", new BigDecimal("21"));
        boolean ivaFallback = item.optBoolean("iva_fallback", false);

        List<PriceTier> tramos = new ArrayList<>();
        JSONArray tramosJson = item.optJSONArray("tramos");
        if (tramosJson != null) {
            for (int i = 0; i < tramosJson.length(); i++) {
                JSONObject tramoObj = tramosJson.optJSONObject(i);
                if (tramoObj == null) {
                    continue;
                }
                BigDecimal qtyMin = parseBigDecimal(tramoObj, "cantidad_minima", ONE);
                if (qtyMin.compareTo(ZERO) <= 0) {
                    qtyMin = ONE;
                }
                BigDecimal price = parseBigDecimal(tramoObj, "precio_base_sin_iva", precioBase);
                if (price.compareTo(ZERO) < 0) {
                    price = ZERO;
                }
                BigDecimal reduction = parseBigDecimal(tramoObj, "reduction", ZERO);
                if (reduction.compareTo(ZERO) < 0) {
                    reduction = ZERO;
                }
                String reductionType = UiText.sanitizeDbValue(tramoObj.optString("reduction_type", "amount"))
                        .toLowerCase(Locale.ROOT);
                if (!reductionType.equals("amount") && !reductionType.equals("percentage")) {
                    reductionType = "amount";
                }
                tramos.add(new PriceTier(qtyMin, price, reduction, reductionType));
            }
        }

        tramos.sort((a, b) -> a.qtyMin.compareTo(b.qtyMin));
        if (tramos.isEmpty()) {
            tramos.add(new PriceTier(ONE, precioBase.max(ZERO), ZERO, "amount"));
        } else if (tramos.get(0).qtyMin.compareTo(ONE) > 0) {
            tramos.add(0, new PriceTier(ONE, precioBase.max(ZERO), ZERO, "amount"));
        }

        return new CatalogProduct(idProduct, codigo, descripcion, precioBase.max(ZERO), ivaPct.max(ZERO), ivaFallback, tramos);
    }

    private void renderSearchResults() {
        if (llResultados == null) {
            return;
        }
        llResultados.removeAllViews();

        if (searchResults.isEmpty()) {
            if (txtResultadosEmpty != null) {
                txtResultadosEmpty.setVisibility(View.VISIBLE);
                if (UiText.sanitizeDbValue(txtResultadosEmpty.getText().toString()).isEmpty()) {
                    txtResultadosEmpty.setText("Sin resultados para esta búsqueda");
                }
            }
            return;
        }

        if (txtResultadosEmpty != null) {
            txtResultadosEmpty.setVisibility(View.GONE);
        }

        List<CatalogProduct> recommended = selectRecommendedProducts(searchResults, MAX_RECOMMENDED_RESULTS);
        for (CatalogProduct product : recommended) {
            View row = getLayoutInflater().inflate(R.layout.item_adicional_resultado, llResultados, false);
            TextView txtCode = row.findViewById(R.id.txtResultadoCodigo);
            TextView txtDesc = row.findViewById(R.id.txtResultadoDescripcion);
            TextView txtMeta = row.findViewById(R.id.txtResultadoMeta);

            txtCode.setText(product.codigo.isEmpty() ? "SIN CÓDIGO" : product.codigo);
            txtDesc.setText(product.descripcion);

            String ivaText = "IVA " + formatPercent(product.ivaPct);
            if (product.ivaFallback) {
                ivaText += " (estimado)";
            }
            ProductUsage usage = usageStats.get(product.idProduct);
            if (usage != null && usage.count > 0) {
                txtMeta.setText(ivaText + " · Recomendado · usado " + usage.count + " veces");
            } else {
                txtMeta.setText(ivaText + " · Recomendado");
            }

            row.setOnClickListener(v -> addOrMergeLine(product));
            llResultados.addView(row);
        }
    }

    private void clearSearchResults(boolean showEmpty) {
        searchResults.clear();
        if (llResultados != null) {
            llResultados.removeAllViews();
        }
        if (txtResultadosEmpty != null) {
            txtResultadosEmpty.setVisibility(showEmpty ? View.VISIBLE : View.GONE);
            if (showEmpty) {
                txtResultadosEmpty.setText("Sin resultados para esta búsqueda");
            }
        }
    }

    private void addOrMergeLine(CatalogProduct product) {
        if (product == null) {
            return;
        }

        BudgetLine line = lineMap.get(product.idProduct);
        if (line == null) {
            line = new BudgetLine(product, ONE, product.descripcion);
            recalculateLine(line);
            lineMap.put(product.idProduct, line);
        } else {
            line.quantity = line.quantity.add(ONE);
            recalculateLine(line);
        }

        registerProductUsage(product);
        renderSearchResults();
        renderBudgetLines();
        updateTotals();
        Toast.makeText(this, "Artículo añadido al presupuesto", Toast.LENGTH_SHORT).show();
    }

    private List<CatalogProduct> selectRecommendedProducts(List<CatalogProduct> candidates, int limit) {
        if (candidates == null || candidates.isEmpty() || limit <= 0) {
            return new ArrayList<>();
        }
        Map<Integer, Integer> originalOrder = new HashMap<>();
        for (int i = 0; i < candidates.size(); i++) {
            originalOrder.put(candidates.get(i).idProduct, i);
        }

        List<CatalogProduct> sorted = new ArrayList<>(candidates);
        sorted.sort((a, b) -> {
            ProductUsage ua = usageStats.get(a.idProduct);
            ProductUsage ub = usageStats.get(b.idProduct);
            boolean aUsed = ua != null && ua.count > 0;
            boolean bUsed = ub != null && ub.count > 0;

            if (aUsed != bUsed) {
                return aUsed ? -1 : 1;
            }
            int countA = ua != null ? ua.count : 0;
            int countB = ub != null ? ub.count : 0;
            int cmpCount = Integer.compare(countB, countA);
            if (cmpCount != 0) {
                return cmpCount;
            }
            long lastA = ua != null ? ua.lastUsedMs : 0L;
            long lastB = ub != null ? ub.lastUsedMs : 0L;
            int cmpLast = Long.compare(lastB, lastA);
            if (cmpLast != 0) {
                return cmpLast;
            }

            int idxA = originalOrder.containsKey(a.idProduct) ? originalOrder.get(a.idProduct) : Integer.MAX_VALUE;
            int idxB = originalOrder.containsKey(b.idProduct) ? originalOrder.get(b.idProduct) : Integer.MAX_VALUE;
            return Integer.compare(idxA, idxB);
        });

        int end = Math.min(limit, sorted.size());
        return new ArrayList<>(sorted.subList(0, end));
    }

    private void registerProductUsage(CatalogProduct product) {
        if (product == null || product.idProduct <= 0) {
            return;
        }
        ProductUsage usage = usageStats.get(product.idProduct);
        if (usage == null) {
            usage = new ProductUsage();
            usageStats.put(product.idProduct, usage);
        }
        usage.count += 1;
        usage.lastUsedMs = System.currentTimeMillis();
        saveUsageStats();
    }

    private void loadUsageStats() {
        usageStats.clear();
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String raw = UiText.sanitizeDbValue(prefs.getString(PREFS_USAGE_KEY, ""));
        if (raw.isEmpty()) {
            return;
        }
        try {
            JSONObject root = new JSONObject(raw);
            JSONArray keys = root.names();
            if (keys == null) {
                return;
            }
            for (int i = 0; i < keys.length(); i++) {
                String key = UiText.sanitizeDbValue(keys.optString(i, ""));
                if (!key.matches("\\d+")) {
                    continue;
                }
                int idProduct = Integer.parseInt(key);
                JSONObject item = root.optJSONObject(key);
                if (item == null) {
                    continue;
                }
                ProductUsage usage = new ProductUsage();
                usage.count = Math.max(0, item.optInt("count", 0));
                usage.lastUsedMs = Math.max(0L, item.optLong("last_used_ms", 0L));
                if (usage.count > 0) {
                    usageStats.put(idProduct, usage);
                }
            }
        } catch (Exception ignored) {
            usageStats.clear();
        }
    }

    private void saveUsageStats() {
        try {
            JSONObject root = new JSONObject();
            for (Map.Entry<Integer, ProductUsage> entry : usageStats.entrySet()) {
                int idProduct = entry.getKey() != null ? entry.getKey() : 0;
                ProductUsage usage = entry.getValue();
                if (idProduct <= 0 || usage == null || usage.count <= 0) {
                    continue;
                }
                JSONObject item = new JSONObject();
                item.put("count", usage.count);
                item.put("last_used_ms", usage.lastUsedMs);
                root.put(String.valueOf(idProduct), item);
            }
            SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
            prefs.edit().putString(PREFS_USAGE_KEY, root.toString()).apply();
        } catch (Exception ignored) {
            // No interrumpe el flujo de presupuesto si falla persistencia local.
        }
    }

    private void renderBudgetLines() {
        if (llLineas == null) {
            return;
        }
        llLineas.removeAllViews();

        if (lineMap.isEmpty()) {
            if (txtLineasVacias != null) {
                txtLineasVacias.setVisibility(View.VISIBLE);
            }
            return;
        }

        if (txtLineasVacias != null) {
            txtLineasVacias.setVisibility(View.GONE);
        }

        for (BudgetLine line : lineMap.values()) {
            View row = getLayoutInflater().inflate(R.layout.item_adicional_linea, llLineas, false);
            EditText edtCantidad = row.findViewById(R.id.edtLineaCantidad);
            Button btnMinus = row.findViewById(R.id.btnLineaMinus);
            Button btnPlus = row.findViewById(R.id.btnLineaPlus);
            TextView txtCodigo = row.findViewById(R.id.txtLineaCodigo);
            EditText edtDescripcion = row.findViewById(R.id.edtLineaDescripcion);
            TextView txtUnit = row.findViewById(R.id.txtLineaPrecioUnitario);
            TextView txtTotal = row.findViewById(R.id.txtLineaPrecioTotal);
            TextView txtIvaInfo = row.findViewById(R.id.txtLineaIvaInfo);
            Button btnEliminar = row.findViewById(R.id.btnLineaEliminar);

            if (btnMinus != null) {
                btnMinus.setAllCaps(false);
                btnMinus.setText("-");
            }
            if (btnPlus != null) {
                btnPlus.setAllCaps(false);
                btnPlus.setText("+");
            }

            txtCodigo.setText(line.product.codigo.isEmpty() ? "SIN CÓDIGO" : line.product.codigo);
            edtCantidad.setText(formatQuantity(line.quantity));
            edtDescripcion.setText(line.description);
            refreshLineAmounts(txtUnit, txtTotal, txtIvaInfo, line);

            final boolean[] updatingQty = {false};

            if (btnMinus != null) {
                btnMinus.setOnClickListener(v -> {
                    line.quantity = stepQuantity(line.quantity, false);
                    recalculateLine(line);
                    updatingQty[0] = true;
                    edtCantidad.setText(formatQuantity(line.quantity));
                    updatingQty[0] = false;
                    edtCantidad.setError(null);
                    refreshLineAmounts(txtUnit, txtTotal, txtIvaInfo, line);
                    updateTotals();
                });
            }
            if (btnPlus != null) {
                btnPlus.setOnClickListener(v -> {
                    line.quantity = stepQuantity(line.quantity, true);
                    recalculateLine(line);
                    updatingQty[0] = true;
                    edtCantidad.setText(formatQuantity(line.quantity));
                    updatingQty[0] = false;
                    edtCantidad.setError(null);
                    refreshLineAmounts(txtUnit, txtTotal, txtIvaInfo, line);
                    updateTotals();
                });
            }

            edtCantidad.addTextChangedListener(new SimpleTextWatcher() {
                @Override
                public void afterTextChanged(Editable s) {
                    if (updatingQty[0]) {
                        return;
                    }
                    String raw = UiText.sanitizeDbValue(s != null ? s.toString() : "");
                    if (raw.isEmpty()) {
                        return;
                    }
                    ValidationResult result = validateQuantity(raw);
                    if (!result.valid) {
                        edtCantidad.setError("Cantidad inválida");
                        return;
                    }
                    edtCantidad.setError(null);
                    line.quantity = result.value;
                    recalculateLine(line);
                    refreshLineAmounts(txtUnit, txtTotal, txtIvaInfo, line);
                    updateTotals();
                }
            });

            edtCantidad.setOnFocusChangeListener((v, hasFocus) -> {
                if (hasFocus) {
                    return;
                }
                String raw = UiText.sanitizeDbValue(edtCantidad.getText() != null ? edtCantidad.getText().toString() : "");
                ValidationResult result = validateQuantity(raw);
                if (!result.valid) {
                    updatingQty[0] = true;
                    edtCantidad.setText(formatQuantity(line.quantity));
                    updatingQty[0] = false;
                    edtCantidad.setError(null);
                    return;
                }
                line.quantity = result.value;
                recalculateLine(line);
                refreshLineAmounts(txtUnit, txtTotal, txtIvaInfo, line);
                updateTotals();
            });

            edtDescripcion.addTextChangedListener(new SimpleTextWatcher() {
                @Override
                public void afterTextChanged(Editable s) {
                    line.description = s == null ? "" : s.toString().trim();
                }
            });

            btnEliminar.setOnClickListener(v -> {
                lineMap.remove(line.product.idProduct);
                renderBudgetLines();
                updateTotals();
            });

            llLineas.addView(row);
        }
    }

    private BigDecimal stepQuantity(BigDecimal current, boolean increment) {
        BigDecimal value = current == null ? ONE : current;
        BigDecimal next = increment ? value.add(ONE) : value.subtract(ONE);
        if (next.compareTo(ONE_TENTH) < 0) {
            next = ONE_TENTH;
        }
        return next.setScale(1, RoundingMode.HALF_UP).stripTrailingZeros();
    }

    private void recalculateLine(BudgetLine line) {
        PriceTier tramo = resolveTier(line.product.tiers, line.quantity);
        BigDecimal base = tramo.basePrice.max(ZERO);

        BigDecimal discount;
        if ("percentage".equals(tramo.reductionType)) {
            BigDecimal reductionFactor = tramo.reduction;
            if (reductionFactor.compareTo(ONE) > 0) {
                // Compatibilidad: si llega "10" lo tratamos como 10%, si llega "0.10" como 10%.
                reductionFactor = reductionFactor.divide(ONE_HUNDRED, 6, RoundingMode.HALF_UP);
            }
            if (reductionFactor.compareTo(ZERO) < 0) {
                reductionFactor = ZERO;
            }
            if (reductionFactor.compareTo(ONE) > 0) {
                reductionFactor = ONE;
            }
            discount = base.multiply(reductionFactor).setScale(6, RoundingMode.HALF_UP);
        } else {
            discount = tramo.reduction;
        }
        if (discount.compareTo(ZERO) < 0) {
            discount = ZERO;
        }

        BigDecimal unitSinIva = base.subtract(discount);
        if (unitSinIva.compareTo(ZERO) < 0) {
            unitSinIva = ZERO;
        }

        BigDecimal ivaMultiplier = ONE.add(line.product.ivaPct.divide(ONE_HUNDRED, 6, RoundingMode.HALF_UP));
        BigDecimal unitConIva = unitSinIva.multiply(ivaMultiplier).setScale(6, RoundingMode.HALF_UP);
        BigDecimal totalSinIva = unitSinIva.multiply(line.quantity).setScale(6, RoundingMode.HALF_UP);
        BigDecimal totalConIva = unitConIva.multiply(line.quantity).setScale(6, RoundingMode.HALF_UP);
        BigDecimal ivaAmount = totalConIva.subtract(totalSinIva).setScale(6, RoundingMode.HALF_UP);

        line.unitSinIva = unitSinIva;
        line.unitConIva = unitConIva;
        line.totalSinIva = totalSinIva;
        line.totalConIva = totalConIva;
        line.ivaAmount = ivaAmount;
    }

    private PriceTier resolveTier(List<PriceTier> tiers, BigDecimal quantity) {
        if (tiers == null || tiers.isEmpty()) {
            return new PriceTier(ONE, ZERO, ZERO, "amount");
        }
        PriceTier selected = tiers.get(0);
        for (PriceTier tier : tiers) {
            if (tier.qtyMin.compareTo(quantity) <= 0) {
                selected = tier;
            } else {
                break;
            }
        }
        return selected;
    }

    private void refreshLineAmounts(TextView txtUnit, TextView txtTotal, TextView txtIvaInfo, BudgetLine line) {
        txtUnit.setText("P. unit: " + formatCurrency(line.unitConIva) + " (IVA incluido)");
        txtTotal.setText("Total: " + formatCurrency(line.totalConIva));
        String ivaLabel = "IVA " + formatPercent(line.product.ivaPct) + " Total s/IVA " + formatCurrency(line.totalSinIva);
        if (line.product.ivaFallback) {
            ivaLabel += " (estimado)";
        }
        txtIvaInfo.setText(ivaLabel);
    }

    private void updateTotals() {
        Totals totals = calculateTotals();

        if (txtSubtotalSinIvaValue != null) {
            txtSubtotalSinIvaValue.setText(formatCurrency(totals.sinIva));
        }
        if (txtIvaValue != null) {
            txtIvaValue.setText(formatCurrency(totals.iva));
        }
        if (txtTotalConIvaValue != null) {
            txtTotalConIvaValue.setText(formatCurrency(totals.conIva));
        }
    }

    private Totals calculateTotals() {
        BigDecimal subtotalSinIva = ZERO;
        BigDecimal totalConIva = ZERO;
        for (BudgetLine line : lineMap.values()) {
            subtotalSinIva = subtotalSinIva.add(line.totalSinIva);
            totalConIva = totalConIva.add(line.totalConIva);
        }
        BigDecimal iva = totalConIva.subtract(subtotalSinIva);
        return new Totals(subtotalSinIva, iva, totalConIva);
    }

    private void setSignatureInputEnabled(boolean enabled) {
        signatureInputEnabled = enabled;
        if (signaturePad != null) {
            signaturePad.setDrawingEnabled(enabled);
            signaturePad.setAlpha(enabled ? 1f : 0.75f);
        }
        if (!enabled) {
            setGlobalRefreshEnabled(true);
        }
        updateSignatureToggleButton();
        updateSignatureHint();
    }

    private void updateSignatureToggleButton() {
        if (btnToggleSignatureInput == null) {
            return;
        }
        boolean active = signatureInputEnabled;
        btnToggleSignatureInput.setText(active
                ? "Desactivar campo firma"
                : "Activar campo firma");

        int bgColor = Color.parseColor(active ? "#FDECEC" : "#E8F7EE");
        int textColor = Color.parseColor(active ? "#A42828" : "#1B7A45");
        int strokeColor = Color.parseColor(active ? "#E78A8A" : "#88C8A1");

        btnToggleSignatureInput.setBackgroundTintList(ColorStateList.valueOf(bgColor));
        btnToggleSignatureInput.setTextColor(textColor);
        if (btnToggleSignatureInput instanceof MaterialButton) {
            ((MaterialButton) btnToggleSignatureInput)
                    .setStrokeColor(ColorStateList.valueOf(strokeColor));
        }
    }

    private void updateSignatureHint() {
        if (txtFirmaHint == null || signaturePad == null) {
            return;
        }
        if (!signatureInputEnabled) {
            if (signaturePad.hasSignature()) {
                txtFirmaHint.setText("Firma capturada. Campo desactivado");
            } else {
                txtFirmaHint.setText("Campo firma desactivado. Pulsa \"Activar campo firma\"");
            }
            return;
        }
        if (signaturePad.hasSignature()) {
            txtFirmaHint.setText("Firma capturada");
        } else {
            txtFirmaHint.setText("Firma aquí con el dedo");
        }
    }

    private ValidationResult validateQuantity(String rawValue) {
        String raw = UiText.sanitizeDbValue(rawValue).replace(",", ".");
        if (!raw.matches("^\\d+(\\.\\d)?$")) {
            return ValidationResult.invalid();
        }
        try {
            BigDecimal qty = new BigDecimal(raw);
            if (qty.compareTo(ZERO) <= 0) {
                return ValidationResult.invalid();
            }
            return ValidationResult.valid(qty);
        } catch (Exception e) {
            return ValidationResult.invalid();
        }
    }

    private String formatCurrency(BigDecimal value) {
        BigDecimal amount = value == null ? ZERO : value;
        return currencyFormat.format(amount.setScale(2, RoundingMode.HALF_UP));
    }

    private String formatPercent(BigDecimal percent) {
        BigDecimal value = percent == null ? ZERO : percent.setScale(2, RoundingMode.HALF_UP).stripTrailingZeros();
        return value.toPlainString() + "%";
    }

    private String formatApiDecimal(BigDecimal value, int scale) {
        BigDecimal safe = value == null ? ZERO : value;
        return safe.setScale(scale, RoundingMode.HALF_UP).toPlainString();
    }

    private String formatQuantity(BigDecimal quantity) {
        if (quantity == null) {
            return "1";
        }
        BigDecimal normalized = quantity.stripTrailingZeros();
        if (normalized.scale() <= 0) {
            return normalized.toPlainString();
        }
        if (normalized.scale() > 1) {
            normalized = normalized.setScale(1, RoundingMode.HALF_UP).stripTrailingZeros();
        }
        return normalized.toPlainString();
    }

    private BigDecimal parseBigDecimal(JSONObject obj, String key, BigDecimal fallback) {
        if (obj == null || key == null || !obj.has(key)) {
            return fallback;
        }
        Object value = obj.opt(key);
        if (value == null) {
            return fallback;
        }
        String raw = UiText.sanitizeDbValue(String.valueOf(value)).replace(",", ".");
        if (raw.isEmpty()) {
            return fallback;
        }
        try {
            return new BigDecimal(raw);
        } catch (Exception e) {
            return fallback;
        }
    }

    private void showLoading(String message) {
        if (txtLoading != null) {
            txtLoading.setVisibility(View.VISIBLE);
            txtLoading.setText(message);
        }
    }

    private void hideLoading() {
        if (txtLoading != null) {
            txtLoading.setVisibility(View.GONE);
        }
        stopPullRefresh();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
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

    private boolean isPedidoValido(String pedido) {
        String clean = UiText.sanitizeDbValue(pedido);
        return !clean.isEmpty() && clean.matches(".*\\d.*");
    }

    private boolean isManualPedido(String pedido) {
        String clean = UiText.sanitizeDbValue(pedido).toUpperCase(Locale.ROOT);
        return clean.startsWith("MANUAL-");
    }

    private interface ReferenceCallback {
        void onReference(String ref);
    }

    private abstract static class SimpleTextWatcher implements TextWatcher {
        @Override
        public void beforeTextChanged(CharSequence s, int start, int count, int after) {
        }

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
        }
    }

    private static final class Totals {
        final BigDecimal sinIva;
        final BigDecimal iva;
        final BigDecimal conIva;

        Totals(BigDecimal sinIva, BigDecimal iva, BigDecimal conIva) {
            this.sinIva = sinIva;
            this.iva = iva;
            this.conIva = conIva;
        }
    }

    private static final class ValidationResult {
        final boolean valid;
        final BigDecimal value;

        private ValidationResult(boolean valid, BigDecimal value) {
            this.valid = valid;
            this.value = value;
        }

        static ValidationResult valid(BigDecimal value) {
            return new ValidationResult(true, value);
        }

        static ValidationResult invalid() {
            return new ValidationResult(false, ZERO);
        }
    }

    private static final class PriceTier {
        final BigDecimal qtyMin;
        final BigDecimal basePrice;
        final BigDecimal reduction;
        final String reductionType;

        PriceTier(BigDecimal qtyMin, BigDecimal basePrice, BigDecimal reduction, String reductionType) {
            this.qtyMin = qtyMin;
            this.basePrice = basePrice;
            this.reduction = reduction;
            this.reductionType = reductionType;
        }
    }

    private static final class CatalogProduct {
        final int idProduct;
        final String codigo;
        final String descripcion;
        final BigDecimal basePrice;
        final BigDecimal ivaPct;
        final boolean ivaFallback;
        final List<PriceTier> tiers;

        CatalogProduct(
                int idProduct,
                String codigo,
                String descripcion,
                BigDecimal basePrice,
                BigDecimal ivaPct,
                boolean ivaFallback,
                List<PriceTier> tiers) {
            this.idProduct = idProduct;
            this.codigo = codigo;
            this.descripcion = descripcion;
            this.basePrice = basePrice;
            this.ivaPct = ivaPct;
            this.ivaFallback = ivaFallback;
            this.tiers = tiers;
        }
    }

    private static final class PresupuestoResumen {
        int idPresupuesto;
        String numeroPedido = "";
        String nombreCliente = "";
        String telefono = "";
        String equipo = "";
        String usuario = "";
        String importeConIva = "0";
        String estado = "";
        String fechaPresupuesto = "";
        boolean mailEnviado = false;
    }

    private static final class BudgetLine {
        final CatalogProduct product;
        BigDecimal quantity;
        String description;
        BigDecimal unitSinIva = ZERO;
        BigDecimal unitConIva = ZERO;
        BigDecimal totalSinIva = ZERO;
        BigDecimal totalConIva = ZERO;
        BigDecimal ivaAmount = ZERO;

        BudgetLine(CatalogProduct product, BigDecimal quantity, String description) {
            this.product = product;
            this.quantity = quantity;
            this.description = description;
        }
    }

    private static final class ProductUsage {
        int count = 0;
        long lastUsedMs = 0L;
    }
}
