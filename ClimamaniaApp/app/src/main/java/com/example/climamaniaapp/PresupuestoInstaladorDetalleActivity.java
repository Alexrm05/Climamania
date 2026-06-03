package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;

import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

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
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class PresupuestoInstaladorDetalleActivity extends BaseActivity {

    private static final String TAG = "PresupuestoDetalle";
    private static final String API_KEY = "TEST123";

    private static final String[] DETALLE_URLS = new String[] {
            "https://app.clminstal.es/api/get_presupuesto_instalador_detalle.php",
            "https://app.clminstal.es/get_presupuesto_instalador_detalle.php",
            "https://clminstal.es/api/get_presupuesto_instalador_detalle.php",
            "https://clminstal.es/get_presupuesto_instalador_detalle.php"
    };

    private static final String[] ACTUALIZAR_URLS = new String[] {
            "https://app.clminstal.es/api/actualizar_presupuesto_instalador.php",
            "https://app.clminstal.es/actualizar_presupuesto_instalador.php",
            "https://clminstal.es/api/actualizar_presupuesto_instalador.php",
            "https://clminstal.es/actualizar_presupuesto_instalador.php"
    };

    private static final String[] CANCELAR_URLS = new String[] {
            "https://app.clminstal.es/api/cancelar_presupuesto_instalador.php",
            "https://app.clminstal.es/api/cancelar_presupuesto_instalador.php",
            "https://clminstal.es/api/cancelar_presupuesto_instalador.php",
            "https://clminstal.es/api/cancelar_presupuesto_instalador.php"
    };

    private static final String[] CATALOGO_URLS = new String[] {
            "https://app.clminstal.es/api/get_adicionales_catalogo.php",
            "https://app.clminstal.es/get_adicionales_catalogo.php",
            "https://clminstal.es/api/get_adicionales_catalogo.php",
            "https://clminstal.es/get_adicionales_catalogo.php"
    };

    private static final BigDecimal ONE = new BigDecimal("1");
    private static final BigDecimal ONE_TENTH = new BigDecimal("0.1");
    private static final BigDecimal ZERO = BigDecimal.ZERO;
    private static final BigDecimal ONE_HUNDRED = new BigDecimal("100");

    private final Handler searchHandler = new Handler(Looper.getMainLooper());
    private final NumberFormat currencyFormat = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-ES"));
    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat displayDateFormat = new SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.forLanguageTag("es-ES"));

    private RequestQueue requestQueue;
    private Runnable pendingSearchRunnable;

    private TextView txtSaludo;
    private TextView txtRef;
    private EditText editNombreCliente;
    private EditText editDireccionCliente;
    private EditText editTelefono;
    private EditText editEmail;
    private TextView txtEstado;
    private TextView txtEquipoUsuario;
    private TextView txtMail;
    private TextView txtLineasVacias;
    private TextView txtResultadosEmpty;
    private TextView txtTotalSinIva;
    private TextView txtTotalIva;
    private TextView txtTotalConIva;
    private LinearLayout llLineas;
    private LinearLayout llResultados;
    private LinearLayout layoutAddSection;
    private EditText editBuscarArticulo;
    private ProgressBar progressBuscar;
    private Button btnGuardar;
    private Button btnCancelar;
    private Button btnPdf;
    private Button btnFirma;

    private int idPresupuesto;
    private boolean canEdit = false;
    private boolean saving = false;
    private boolean canceling = false;

    private String rolActual = "";
    private String usuarioActual = "";
    private String equipoActual = "";
    private String numeroPedido = "";
    private String pdfUrl = "";
    private String firmaUrl = "";
    private String estadoActual = "";

    private long nextLocalLineId = 1;
    private final LinkedHashMap<Long, EditableLine> lineMap = new LinkedHashMap<>();
    private final List<CatalogProduct> searchResults = new ArrayList<>();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_presupuesto_detalle, contentFrame, true);

        setupBottomBar();

        requestQueue = Volley.newRequestQueue(this);
        currencyFormat.setMinimumFractionDigits(2);
        currencyFormat.setMaximumFractionDigits(2);

        txtSaludo = content.findViewById(R.id.txtPresDetalleSaludo);
        txtRef = content.findViewById(R.id.txtPresDetalleRef);
        editNombreCliente = content.findViewById(R.id.editPresNombreCliente);
        editDireccionCliente = content.findViewById(R.id.editPresDireccionCliente);
        editTelefono = content.findViewById(R.id.editPresTelefono);
        editEmail = content.findViewById(R.id.editPresEmail);
        txtEstado = content.findViewById(R.id.txtPresDetalleEstado);
        txtEquipoUsuario = content.findViewById(R.id.txtPresDetalleEquipoUsuario);
        txtMail = content.findViewById(R.id.txtPresDetalleMail);
        txtLineasVacias = content.findViewById(R.id.txtPresDetalleLineasVacias);
        txtResultadosEmpty = content.findViewById(R.id.txtPresDetalleResultadosEmpty);
        txtTotalSinIva = content.findViewById(R.id.txtPresDetalleTotalSinIva);
        txtTotalIva = content.findViewById(R.id.txtPresDetalleTotalIva);
        txtTotalConIva = content.findViewById(R.id.txtPresDetalleTotalConIva);
        llLineas = content.findViewById(R.id.llPresDetalleLineas);
        llResultados = content.findViewById(R.id.llPresDetalleResultados);
        layoutAddSection = content.findViewById(R.id.layoutPresDetalleAddSection);
        editBuscarArticulo = content.findViewById(R.id.editPresDetalleBuscarArticulo);
        progressBuscar = content.findViewById(R.id.progressPresDetalleBuscar);
        btnGuardar = content.findViewById(R.id.btnPresDetalleGuardar);
        btnCancelar = content.findViewById(R.id.btnPresDetalleCancelar);
        btnPdf = content.findViewById(R.id.btnPresDetalleOpenPdf);
        btnFirma = content.findViewById(R.id.btnPresDetalleOpenFirma);
        Button btnVolver = content.findViewById(R.id.btnPresDetalleVolver);

        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
        if (btnPdf != null) {
            btnPdf.setOnClickListener(v -> openPdfUrl(pdfUrl));
        }
        if (btnFirma != null) {
            btnFirma.setOnClickListener(v -> openUrl(firmaUrl));
        }
        if (btnGuardar != null) {
            btnGuardar.setOnClickListener(v -> saveChanges());
        }
        if (btnCancelar != null) {
            btnCancelar.setOnClickListener(v -> confirmCancelPresupuesto());
        }

        bindUserHeader();

        String idRaw = UiText.sanitizeDbValue(getIntent().getStringExtra("id_presupuesto"));
        if (idRaw.isEmpty()) {
            idPresupuesto = getIntent().getIntExtra("id_presupuesto_int", 0);
        } else {
            try {
                idPresupuesto = Integer.parseInt(idRaw);
            } catch (Exception e) {
                idPresupuesto = 0;
            }
        }

        if (idPresupuesto <= 0) {
            Toast.makeText(this, "ID de presupuesto no válido", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        if (txtRef != null) {
            txtRef.setText("Presupuesto #" + idPresupuesto);
        }

        setupSearchInput();
        loadDetalle();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (pendingSearchRunnable != null) {
            searchHandler.removeCallbacks(pendingSearchRunnable);
        }
        if (requestQueue != null) {
            requestQueue.cancelAll("presupuesto_detalle");
            requestQueue.cancelAll("presupuesto_update");
            requestQueue.cancelAll("presupuesto_cancel");
            requestQueue.cancelAll("presupuesto_catalogo");
        }
    }

    private void bindUserHeader() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        rolActual = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        usuarioActual = usuario;
        equipoActual = readEquipoFromPrefs(prefs);

        String displayName = !nombre.isEmpty() ? nombre : (!usuario.isEmpty() ? usuario : "instalador");
        if (txtSaludo != null) {
            txtSaludo.setText("Hola " + displayName);
        }
    }

    private void setupSearchInput() {
        if (editBuscarArticulo == null) {
            return;
        }

        editBuscarArticulo.addTextChangedListener(new SimpleTextWatcher() {
            @Override
            public void afterTextChanged(Editable s) {
                if (!canEdit) {
                    return;
                }
                String query = UiText.sanitizeDbValue(s != null ? s.toString() : "");
                if (pendingSearchRunnable != null) {
                    searchHandler.removeCallbacks(pendingSearchRunnable);
                }
                pendingSearchRunnable = () -> searchCatalog(query);
                searchHandler.postDelayed(pendingSearchRunnable, 300L);
            }
        });
    }

    private void loadDetalle() {
        loadDetalleWithFallback(0, "");
    }

    private void loadDetalleWithFallback(int index, String lastError) {
        if (index >= DETALLE_URLS.length) {
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo cargar el presupuesto";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        try {
            String baseUrl = DETALLE_URLS[index];
            String url = baseUrl
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&id_presupuesto=" + URLEncoder.encode(String.valueOf(idPresupuesto), "UTF-8")
                    + "&rol=" + URLEncoder.encode(rolActual, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuarioActual, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipoActual, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> {
                        String parseError = parseDetalleResponse(response, endpointLabel(baseUrl));
                        if (parseError == null) {
                            return;
                        }
                        loadDetalleWithFallback(index + 1, parseError);
                    },
                    error -> {
                        String errorMessage = buildVolleyErrorMessage(error, "No se pudo cargar el presupuesto");
                        Log.w(TAG, "Error detalle en [" + index + "] " + baseUrl + ": " + errorMessage);
                        loadDetalleWithFallback(index + 1, errorMessage);
                    }
            );
            request.setShouldCache(false);
            request.setTag("presupuesto_detalle");
            requestQueue.add(request);
        } catch (Exception e) {
            loadDetalleWithFallback(index + 1, "No se pudo cargar el presupuesto");
        }
    }

    @Nullable
    private String parseDetalleResponse(String response, String sourceLabel) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = getJsonMessage(root, "No se pudo cargar el presupuesto");
                Log.w(TAG, "Detalle success=false en " + sourceLabel + ": " + message);
                return message;
            }

            JSONObject presupuesto = root.optJSONObject("presupuesto");
            JSONArray lineas = root.optJSONArray("lineas");
            if (presupuesto == null) {
                return "Detalle de presupuesto no disponible";
            }

            bindHeader(presupuesto);
            bindLineas(lineas);
            canEdit = root.optBoolean("can_edit", false) && !isEstadoCancelado(estadoActual);
            applyEditPermissions();

            if (canEdit) {
                searchCatalog("");
            } else {
                clearSearchResults(false);
            }
            return null;
        } catch (Exception e) {
            String error = "Respuesta inválida del servidor";
            Log.w(TAG, error + " en " + sourceLabel, e);
            return error;
        }
    }

    private void bindHeader(JSONObject presupuesto) {
        numeroPedido = UiText.sanitizeDbValue(presupuesto.optString("numero_pedido", ""));
        pdfUrl = UiText.sanitizeDbValue(presupuesto.optString("pdf_url", ""));
        if (pdfUrl.isEmpty()) {
            pdfUrl = UiText.sanitizeDbValue(presupuesto.optString("pdf", ""));
        }
        pdfUrl = ensureAbsoluteUrl(pdfUrl);
        firmaUrl = UiText.sanitizeDbValue(presupuesto.optString("foto_firma_url", ""));
        if (firmaUrl.isEmpty()) {
            firmaUrl = UiText.sanitizeDbValue(presupuesto.optString("foto_firma", ""));
        }
        firmaUrl = ensureAbsoluteUrl(firmaUrl);

        String nombreCliente = UiText.sanitizeDbValue(presupuesto.optString("nombre_cliente", ""));
        String direccionCliente = UiText.sanitizeDbValue(presupuesto.optString("direccion_cliente", ""));
        String telefono = UiText.sanitizeDbValue(presupuesto.optString("telefono", ""));
        String email = UiText.sanitizeDbValue(presupuesto.optString("email_cliente", ""));
        String estado = UiText.sanitizeDbValue(presupuesto.optString("estado", ""));
        estadoActual = estado;
        String equipo = UiText.sanitizeDbValue(presupuesto.optString("equipo_instaladores", ""));
        String usuario = UiText.sanitizeDbValue(presupuesto.optString("usuario_instalador", ""));
        String fechaPresupuesto = formatFecha(UiText.sanitizeDbValue(presupuesto.optString("fecha_presupuesto", "")));
        boolean mailEnviado = presupuesto.optBoolean("mail_enviado", false);
        String fechaMail = formatFecha(UiText.sanitizeDbValue(presupuesto.optString("fecha_envio_mail", "")));

        if (txtRef != null) {
            String numeroText = numeroPedido.isEmpty() ? "-" : numeroPedido;
            txtRef.setText("Presupuesto #" + idPresupuesto + " · Pedido " + numeroText);
        }
        if (editNombreCliente != null) {
            editNombreCliente.setText(nombreCliente);
        }
        if (editDireccionCliente != null) {
            editDireccionCliente.setText(direccionCliente);
        }
        if (editTelefono != null) {
            editTelefono.setText(telefono);
        }
        if (editEmail != null) {
            editEmail.setText(email);
        }
        if (txtEstado != null) {
            txtEstado.setText("Estado: " + (estado.isEmpty() ? "N/D" : estado));
        }
        if (txtEquipoUsuario != null) {
            txtEquipoUsuario.setText("Equipo " + (equipo.isEmpty() ? "N/D" : equipo)
                    + " · Usuario " + (usuario.isEmpty() ? "N/D" : usuario)
                    + " · " + (fechaPresupuesto.isEmpty() ? "" : fechaPresupuesto));
        }
        if (txtMail != null) {
            String mailStatus = mailEnviado ? "enviado" : "pendiente/error";
            String mailMeta = fechaMail.isEmpty() ? "" : (" · " + fechaMail);
            txtMail.setText("Mail: " + mailStatus + mailMeta);
        }

        BigDecimal totalSinIva = parseBigDecimal(presupuesto, "importe_sin_iva", ZERO);
        BigDecimal totalIva = parseBigDecimal(presupuesto, "importe_iva", ZERO);
        BigDecimal totalConIva = parseBigDecimal(presupuesto, "importe_con_iva", ZERO);
        updateTotalsLabels(totalSinIva, totalIva, totalConIva);
    }

    private void bindLineas(@Nullable JSONArray lineas) {
        lineMap.clear();
        nextLocalLineId = 1;

        if (lineas != null) {
            for (int i = 0; i < lineas.length(); i++) {
                JSONObject item = lineas.optJSONObject(i);
                if (item == null) {
                    continue;
                }

                EditableLine line = new EditableLine();
                line.localId = nextLocalLineId++;
                line.catalogProductId = null;
                line.product = null;
                line.articulo = UiText.sanitizeDbValue(item.optString("articulo", ""));
                if (line.articulo.isEmpty()) {
                    line.articulo = "SIN-CODIGO";
                }
                line.description = UiText.sanitizeDbValue(item.optString("descripcion", ""));
                if (line.description.isEmpty()) {
                    line.description = "Sin descripción";
                }

                line.quantity = parseBigDecimal(item, "cantidad", ONE);
                if (line.quantity.compareTo(ZERO) <= 0) {
                    line.quantity = ONE;
                }

                line.fixedUnitSinIva = parseBigDecimal(item, "precio_unitario_sin_iva", ZERO);
                if (line.fixedUnitSinIva.compareTo(ZERO) < 0) {
                    line.fixedUnitSinIva = ZERO;
                }
                line.ivaPct = parseBigDecimal(item, "iva_pct", new BigDecimal("21"));
                if (line.ivaPct.compareTo(ZERO) < 0) {
                    line.ivaPct = ZERO;
                }
                line.ivaFallback = item.optBoolean("iva_fallback", false);

                recalculateLine(line);
                lineMap.put(line.localId, line);
            }
        }

        renderLineas();
        updateTotals();
    }

    private void applyEditPermissions() {
        setEditEnabled(editNombreCliente, canEdit);
        setEditEnabled(editDireccionCliente, canEdit);
        setEditEnabled(editTelefono, canEdit);
        setEditEnabled(editEmail, canEdit);

        if (layoutAddSection != null) {
            layoutAddSection.setVisibility(canEdit ? View.VISIBLE : View.GONE);
        }
        if (btnGuardar != null) {
            btnGuardar.setVisibility(canEdit ? View.VISIBLE : View.GONE);
        }
        if (btnCancelar != null) {
            btnCancelar.setVisibility(!isEstadoCancelado(estadoActual) ? View.VISIBLE : View.GONE);
            btnCancelar.setEnabled(!canceling);
            btnCancelar.setText(canceling ? "Cancelando..." : "Cancelar presupuesto");
        }

        renderLineas();
    }

    private void setEditEnabled(@Nullable EditText edit, boolean enabled) {
        if (edit == null) {
            return;
        }
        edit.setEnabled(enabled);
        edit.setFocusable(enabled);
        edit.setFocusableInTouchMode(enabled);
        edit.setClickable(enabled);
        edit.setLongClickable(enabled);
        edit.setCursorVisible(enabled);
    }

    private void renderLineas() {
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

        for (EditableLine line : lineMap.values()) {
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

            txtCodigo.setText(line.articulo);
            edtCantidad.setText(formatQuantity(line.quantity));
            edtDescripcion.setText(line.description);
            refreshLineAmounts(txtUnit, txtTotal, txtIvaInfo, line);

            if (!canEdit) {
                setEditEnabled(edtCantidad, false);
                setEditEnabled(edtDescripcion, false);
                btnEliminar.setVisibility(View.GONE);
                if (btnMinus != null) {
                    btnMinus.setVisibility(View.GONE);
                }
                if (btnPlus != null) {
                    btnPlus.setVisibility(View.GONE);
                }
                llLineas.addView(row);
                continue;
            }

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
                lineMap.remove(line.localId);
                renderLineas();
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

    private void recalculateLine(EditableLine line) {
        if (line.product != null) {
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

            line.unitSinIva = unitSinIva;
            line.ivaPct = line.product.ivaPct.max(ZERO);
            line.ivaFallback = line.product.ivaFallback;
        } else {
            line.unitSinIva = line.fixedUnitSinIva.max(ZERO);
            line.ivaPct = line.ivaPct.max(ZERO);
        }

        BigDecimal ivaMultiplier = ONE.add(line.ivaPct.divide(ONE_HUNDRED, 6, RoundingMode.HALF_UP));
        line.unitConIva = line.unitSinIva.multiply(ivaMultiplier).setScale(6, RoundingMode.HALF_UP);
        line.totalSinIva = line.unitSinIva.multiply(line.quantity).setScale(6, RoundingMode.HALF_UP);
        line.totalConIva = line.unitConIva.multiply(line.quantity).setScale(6, RoundingMode.HALF_UP);
        line.ivaAmount = line.totalConIva.subtract(line.totalSinIva).setScale(6, RoundingMode.HALF_UP);
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

    private void refreshLineAmounts(TextView txtUnit, TextView txtTotal, TextView txtIvaInfo, EditableLine line) {
        txtUnit.setText("P. unit: " + formatCurrency(line.unitConIva) + " (IVA incluido)");
        txtTotal.setText("Total: " + formatCurrency(line.totalConIva));
        String ivaLabel = "IVA " + formatPercent(line.ivaPct) + " Total s/IVA " + formatCurrency(line.totalSinIva);
        if (line.ivaFallback) {
            ivaLabel += " (estimado)";
        }
        txtIvaInfo.setText(ivaLabel);
    }

    private void updateTotals() {
        BigDecimal subtotalSinIva = ZERO;
        BigDecimal totalConIva = ZERO;
        for (EditableLine line : lineMap.values()) {
            subtotalSinIva = subtotalSinIva.add(line.totalSinIva);
            totalConIva = totalConIva.add(line.totalConIva);
        }
        BigDecimal iva = totalConIva.subtract(subtotalSinIva);
        updateTotalsLabels(subtotalSinIva, iva, totalConIva);
    }

    private void updateTotalsLabels(BigDecimal subtotalSinIva, BigDecimal iva, BigDecimal totalConIva) {
        if (txtTotalSinIva != null) {
            txtTotalSinIva.setText("Total sin IVA: " + formatCurrency(subtotalSinIva));
        }
        if (txtTotalIva != null) {
            txtTotalIva.setText("IVA: " + formatCurrency(iva));
        }
        if (txtTotalConIva != null) {
            txtTotalConIva.setText("Total con IVA: " + formatCurrency(totalConIva));
        }
    }

    private void searchCatalog(String query) {
        if (!canEdit) {
            return;
        }
        if (progressBuscar != null) {
            progressBuscar.setVisibility(View.VISIBLE);
        }
        searchCatalogWithFallback(query, 0, "");
    }

    private void searchCatalogWithFallback(String query, int index, String lastError) {
        if (index >= CATALOGO_URLS.length) {
            if (progressBuscar != null) {
                progressBuscar.setVisibility(View.GONE);
            }
            clearSearchResults(true);
            if (txtResultadosEmpty != null) {
                String message = UiText.sanitizeDbValue(lastError);
                if (message.isEmpty()) {
                    message = "No se pudo cargar el catálogo";
                }
                txtResultadosEmpty.setText(message);
            }
            return;
        }

        try {
            String baseUrl = CATALOGO_URLS[index];
            String url = baseUrl
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&q=" + URLEncoder.encode(query, "UTF-8")
                    + "&limit=20"
                    + "&_ts=" + System.currentTimeMillis();

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    response -> {
                        String parseError = parseCatalogResponse(response, endpointLabel(baseUrl));
                        if (parseError == null) {
                            if (progressBuscar != null) {
                                progressBuscar.setVisibility(View.GONE);
                            }
                            return;
                        }
                        searchCatalogWithFallback(query, index + 1, parseError);
                    },
                    error -> {
                        String errorMessage = buildVolleyErrorMessage(error, "No se pudo cargar el catálogo");
                        searchCatalogWithFallback(query, index + 1, errorMessage);
                    }
            );
            request.setShouldCache(false);
            request.setTag("presupuesto_catalogo");
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
            return null;
        } catch (Exception e) {
            String error = "Respuesta inválida del catálogo";
            Log.w(TAG, error + " en " + sourceLabel, e);
            return error;
        }
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
                txtResultadosEmpty.setText("Sin resultados para esta búsqueda");
            }
            return;
        }

        if (txtResultadosEmpty != null) {
            txtResultadosEmpty.setVisibility(View.GONE);
        }

        for (CatalogProduct product : searchResults) {
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
            txtMeta.setText(ivaText + " · Tocar para añadir");

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
        if (!canEdit || product == null) {
            return;
        }

        EditableLine existing = null;
        for (EditableLine line : lineMap.values()) {
            if (line.catalogProductId != null && line.catalogProductId == product.idProduct) {
                existing = line;
                break;
            }
        }

        if (existing == null) {
            EditableLine line = new EditableLine();
            line.localId = nextLocalLineId++;
            line.catalogProductId = product.idProduct;
            line.product = product;
            line.articulo = product.codigo.isEmpty() ? "SIN-CODIGO" : product.codigo;
            line.description = product.descripcion;
            line.quantity = ONE;
            line.fixedUnitSinIva = ZERO;
            line.ivaPct = product.ivaPct;
            line.ivaFallback = product.ivaFallback;
            recalculateLine(line);
            lineMap.put(line.localId, line);
        } else {
            existing.quantity = existing.quantity.add(ONE);
            recalculateLine(existing);
        }

        renderLineas();
        updateTotals();
        Toast.makeText(this, "Artículo añadido", Toast.LENGTH_SHORT).show();
    }

    private void saveChanges() {
        if (!canEdit) {
            Toast.makeText(this, "No tienes permiso para editar", Toast.LENGTH_SHORT).show();
            return;
        }
        if (saving) {
            return;
        }
        if (lineMap.isEmpty()) {
            Toast.makeText(this, "Añade al menos una línea", Toast.LENGTH_SHORT).show();
            return;
        }

        String nombre = UiText.sanitizeDbValue(editNombreCliente != null && editNombreCliente.getText() != null
                ? editNombreCliente.getText().toString() : "");
        String direccion = UiText.sanitizeDbValue(editDireccionCliente != null && editDireccionCliente.getText() != null
                ? editDireccionCliente.getText().toString() : "");
        String telefono = UiText.sanitizeDbValue(editTelefono != null && editTelefono.getText() != null
                ? editTelefono.getText().toString() : "");
        String email = UiText.sanitizeDbValue(editEmail != null && editEmail.getText() != null
                ? editEmail.getText().toString() : "");

        JSONArray lineasJson = buildLineasPayload();
        if (lineasJson.length() == 0) {
            Toast.makeText(this, "No hay líneas válidas para guardar", Toast.LENGTH_SHORT).show();
            return;
        }

        Map<String, String> payload = new HashMap<>();
        payload.put("api_key", API_KEY);
        payload.put("id_presupuesto", String.valueOf(idPresupuesto));
        payload.put("rol", rolActual);
        payload.put("usuario", usuarioActual);
        payload.put("equipo", equipoActual);
        payload.put("nombre_cliente", nombre);
        payload.put("direccion_cliente", direccion);
        payload.put("telefono", telefono);
        payload.put("email_cliente", email);
        payload.put("lineas_json", lineasJson.toString());

        setSaving(true);
        saveWithFallback(payload, 0, "");
    }

    private JSONArray buildLineasPayload() {
        JSONArray arr = new JSONArray();
        int orden = 1;
        for (EditableLine line : lineMap.values()) {
            try {
                JSONObject obj = new JSONObject();
                obj.put("orden", orden);
                obj.put("cantidad", formatApiDecimal(line.quantity, 2));
                obj.put("articulo", line.articulo.isEmpty() ? "SIN-CODIGO" : line.articulo);
                obj.put("descripcion", line.description.isEmpty() ? "Sin descripción" : line.description);
                obj.put("precio_unitario_sin_iva", formatApiDecimal(line.unitSinIva, 6));
                obj.put("precio_total_linea_sin_iva", formatApiDecimal(line.totalSinIva, 2));
                obj.put("iva_pct", formatApiDecimal(line.ivaPct, 3));
                obj.put("precio_total_linea_con_iva", formatApiDecimal(line.totalConIva, 2));
                obj.put("iva_fallback", line.ivaFallback);
                arr.put(obj);
                orden++;
            } catch (Exception ignored) {
                // Ignorar línea corrupta.
            }
        }
        return arr;
    }

    private void saveWithFallback(Map<String, String> payload, int index, String lastError) {
        if (index >= ACTUALIZAR_URLS.length) {
            setSaving(false);
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo actualizar el presupuesto";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            return;
        }

        String baseUrl = ACTUALIZAR_URLS[index];
        StringRequest request = new StringRequest(
                Request.Method.POST,
                baseUrl,
                response -> {
                    String parseError = parseSaveResponse(response, endpointLabel(baseUrl));
                    if (parseError == null) {
                        return;
                    }
                    saveWithFallback(payload, index + 1, parseError);
                },
                error -> {
                    String errorMessage = buildVolleyErrorMessage(error, "No se pudo actualizar el presupuesto");
                    saveWithFallback(payload, index + 1, errorMessage);
                }
        ) {
            @Override
            protected Map<String, String> getParams() {
                return payload;
            }
        };
        request.setShouldCache(false);
        request.setTag("presupuesto_update");
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        requestQueue.add(request);
    }

    @Nullable
    private String parseSaveResponse(String response, String sourceLabel) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = getJsonMessage(root, "No se pudo actualizar el presupuesto");
                Log.w(TAG, "Actualizar success=false en " + sourceLabel + ": " + message);
                return message;
            }

            setSaving(false);
            String message = getJsonMessage(root, "Presupuesto actualizado");
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

    private void setSaving(boolean value) {
        saving = value;
        if (btnGuardar != null) {
            btnGuardar.setEnabled(!value);
            btnGuardar.setText(value ? "Guardando..." : "Guardar cambios");
        }
        if (btnCancelar != null) {
            btnCancelar.setEnabled(!value && !canceling);
        }
    }

    private void confirmCancelPresupuesto() {
        if (isEstadoCancelado(estadoActual)) {
            Toast.makeText(this, "Este presupuesto no se puede cancelar", Toast.LENGTH_SHORT).show();
            return;
        }
        if (canceling || saving) {
            return;
        }

        new androidx.appcompat.app.AlertDialog.Builder(this)
                .setTitle("Cancelar presupuesto")
                .setMessage("El presupuesto pasará a estado cancelado y se notificará por email a los destinatarios internos.")
                .setNegativeButton("Volver", null)
                .setPositiveButton("Cancelar presupuesto", (dialog, which) -> cancelPresupuesto())
                .show();
    }

    private void cancelPresupuesto() {
        if (isEstadoCancelado(estadoActual)) {
            Toast.makeText(this, "Este presupuesto no se puede cancelar", Toast.LENGTH_SHORT).show();
            return;
        }
        if (canceling) {
            return;
        }

        canceling = true;
        applyEditPermissions();
        cancelWithFallback(0, "");
    }

    private void cancelWithFallback(int index, String lastError) {
        if (index >= CANCELAR_URLS.length) {
            canceling = false;
            applyEditPermissions();
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo cancelar el presupuesto";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            return;
        }

        String baseUrl = CANCELAR_URLS[index];
        StringRequest request = new StringRequest(
                Request.Method.POST,
                baseUrl,
                response -> {
                    String parseError = parseCancelResponse(response, endpointLabel(baseUrl));
                    if (parseError == null) {
                        return;
                    }
                    cancelWithFallback(index + 1, parseError);
                },
                error -> {
                    String errorMessage = buildVolleyErrorMessage(error, "No se pudo cancelar el presupuesto");
                    cancelWithFallback(index + 1, errorMessage);
                }
        ) {
            @Override
            protected Map<String, String> getParams() {
                Map<String, String> payload = new HashMap<>();
                payload.put("api_key", API_KEY);
                payload.put("id_presupuesto", String.valueOf(idPresupuesto));
                payload.put("rol", rolActual);
                payload.put("usuario", usuarioActual);
                payload.put("equipo", equipoActual);
                return payload;
            }
        };
        request.setShouldCache(false);
        request.setTag("presupuesto_cancel");
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        requestQueue.add(request);
    }

    @Nullable
    private String parseCancelResponse(String response, String sourceLabel) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = getJsonMessage(root, "No se pudo cancelar el presupuesto");
                Log.w(TAG, "Cancelar success=false en " + sourceLabel + ": " + message);
                return message;
            }

            canceling = false;
            String message = getJsonMessage(root, "Presupuesto cancelado");
            Toast.makeText(this, message, Toast.LENGTH_LONG).show();
            setResult(RESULT_OK);
            loadDetalle();
            return null;
        } catch (Exception e) {
            String message = "Respuesta inválida del servidor";
            Log.w(TAG, message + " en " + sourceLabel, e);
            return message;
        }
    }

    private void openUrl(String url) {
        String clean = UiText.sanitizeDbValue(url);
        if (clean.isEmpty()) {
            Toast.makeText(this, "Fichero no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        Intent intent = new Intent(this, WebViewActivity.class);
        intent.putExtra("target_url", clean);
        startActivity(intent);
    }

    private void openPdfUrl(String url) {
        String clean = UiText.sanitizeDbValue(url);
        if (clean.isEmpty()) {
            Toast.makeText(this, "PDF no disponible", Toast.LENGTH_SHORT).show();
            return;
        }

        try {
            Intent openExternal = new Intent(Intent.ACTION_VIEW, Uri.parse(clean));
            startActivity(openExternal);
        } catch (Exception e) {
            // Fallback interno si no hay app externa para PDF.
            Intent intent = new Intent(this, WebViewActivity.class);
            intent.putExtra("target_url", clean);
            startActivity(intent);
        }
    }

    private String ensureAbsoluteUrl(String value) {
        String clean = UiText.sanitizeDbValue(value);
        if (clean.isEmpty()) {
            return "";
        }
        if (clean.startsWith("http://") || clean.startsWith("https://")) {
            return clean;
        }
        if (clean.startsWith("/")) {
            return "https://clminstal.es" + clean;
        }
        return "https://clminstal.es/" + clean;
    }

    private String endpointLabel(String url) {
        String clean = UiText.sanitizeDbValue(url);
        if (clean.isEmpty()) {
            return "endpoint desconocido";
        }
        return clean.replace("https://", "");
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

    private boolean isEstadoCancelado(String estado) {
        return "CANCELADO".equalsIgnoreCase(UiText.sanitizeDbValue(estado));
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

    private String formatFecha(String rawDate) {
        String raw = UiText.sanitizeDbValue(rawDate);
        if (raw.isEmpty()) {
            return "";
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
            // Legacy int stored in prefs.
        }
        return String.valueOf(prefs.getInt("equipoInstaladores", 0));
    }

    private abstract static class SimpleTextWatcher implements TextWatcher {
        @Override
        public void beforeTextChanged(CharSequence s, int start, int count, int after) {
        }

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
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

    private static final class EditableLine {
        long localId;
        Integer catalogProductId;
        CatalogProduct product;
        String articulo = "SIN-CODIGO";
        String description = "Sin descripción";
        BigDecimal quantity = ONE;
        BigDecimal fixedUnitSinIva = ZERO;
        BigDecimal ivaPct = new BigDecimal("21");
        boolean ivaFallback = false;
        BigDecimal unitSinIva = ZERO;
        BigDecimal unitConIva = ZERO;
        BigDecimal totalSinIva = ZERO;
        BigDecimal totalConIva = ZERO;
        BigDecimal ivaAmount = ZERO;
    }
}
