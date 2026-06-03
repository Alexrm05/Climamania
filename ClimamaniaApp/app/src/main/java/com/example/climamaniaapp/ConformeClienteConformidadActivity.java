package com.example.climamaniaapp;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
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

import org.json.JSONObject;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class ConformeClienteConformidadActivity extends BaseActivity {

    private static final String API_KEY = "TEST123";
    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String[] GENERATE_PDF_URLS = new String[] {
            "https://app.clminstal.es/api/generar_conforme_cliente_pdf.php"
    };

    private RequestQueue requestQueue;
    private EventLocationCaptureHelper locationCaptureHelper;

    private String referencia;
    private String cliente;
    private String pedidoJson;
    private boolean requiereBoe;
    private boolean revisionBoeGuardada;
    private String submissionToken = "";
    private boolean generatingPdf = false;

    private ConformidadData conformidadData;
    private boolean updatingSignerSelection = false;

    private TextView txtReferencia;
    private TextView txtCliente;
    private TextView txtDocumento;
    private TextView txtFirmaContexto;
    private TextView txtFirmaPieNombre;
    private TextView txtFirmaPieDni;
    private CheckBox cbClienteTitular;
    private CheckBox cbRepresentante;
    private LinearLayout llRepresentante;
    private TextView txtRepresentanteAviso;
    private EditText editObservaciones;
    private EditText editRepresentanteNombre;
    private EditText editRepresentanteApellidos;
    private EditText editRepresentanteDni;
    private SignaturePadView signaturePad;
    private Button btnLimpiarFirma;
    private Button btnAceptar;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(
                R.layout.content_conforme_cliente_conformidad,
                contentFrame,
                true
        );
        setupBottomBar();

        requestQueue = Volley.newRequestQueue(this);
        locationCaptureHelper = new EventLocationCaptureHelper(this);

        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));
        pedidoJson = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido_json"));
        requiereBoe = getIntent().getBooleanExtra("requiere_boe", false);
        revisionBoeGuardada = getIntent().getBooleanExtra("revision_boe_guardada", false);

        txtReferencia = content.findViewById(R.id.txtConformeReferencia);
        txtCliente = content.findViewById(R.id.txtConformeCliente);
        txtDocumento = content.findViewById(R.id.txtConformeDocumento);
        txtFirmaContexto = content.findViewById(R.id.txtConformeFirmaContexto);
        txtFirmaPieNombre = content.findViewById(R.id.txtConformeFirmaPieNombre);
        txtFirmaPieDni = content.findViewById(R.id.txtConformeFirmaPieDni);
        cbClienteTitular = content.findViewById(R.id.chkConformeClienteTitular);
        cbRepresentante = content.findViewById(R.id.chkConformeRepresentante);
        llRepresentante = content.findViewById(R.id.llConformeRepresentante);
        txtRepresentanteAviso = content.findViewById(R.id.txtConformeRepresentanteAviso);
        editObservaciones = content.findViewById(R.id.editConformeObservaciones);
        editRepresentanteNombre = content.findViewById(R.id.editConformeRepresentanteNombre);
        editRepresentanteApellidos = content.findViewById(R.id.editConformeRepresentanteApellidos);
        editRepresentanteDni = content.findViewById(R.id.editConformeRepresentanteDni);
        signaturePad = content.findViewById(R.id.signaturePadConforme);
        btnLimpiarFirma = content.findViewById(R.id.btnConformeLimpiarFirma);
        btnAceptar = content.findViewById(R.id.btnConformeAceptar);
        Button btnVolver = content.findViewById(R.id.btnConformeVolver);

        UiText.setTextOrPlaceholder(txtReferencia, referencia, "Referencia no disponible");
        UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");

        if (cbClienteTitular != null) {
            cbClienteTitular.setOnCheckedChangeListener((buttonView, isChecked) -> onSignerCheckboxChanged(true, isChecked));
        }
        if (cbRepresentante != null) {
            cbRepresentante.setOnCheckedChangeListener((buttonView, isChecked) -> onSignerCheckboxChanged(false, isChecked));
        }

        TextWatcher representativeWatcher = new SimpleTextWatcher() {
            @Override
            public void afterTextChanged(Editable s) {
                onRepresentativeFieldsChanged();
            }
        };
        if (editRepresentanteNombre != null) {
            editRepresentanteNombre.addTextChangedListener(representativeWatcher);
        }
        if (editRepresentanteApellidos != null) {
            editRepresentanteApellidos.addTextChangedListener(representativeWatcher);
        }
        if (editRepresentanteDni != null) {
            editRepresentanteDni.addTextChangedListener(representativeWatcher);
        }

        if (signaturePad != null) {
            signaturePad.setDrawingEnabled(false);
            signaturePad.setAlpha(0.45f);
            signaturePad.setOnSignatureStateChangedListener(hasSignature -> updateValidationState(false));
        }
        if (btnLimpiarFirma != null) {
            btnLimpiarFirma.setOnClickListener(v -> {
                if (signaturePad != null) {
                    signaturePad.clear();
                }
            });
        }
        if (btnAceptar != null) {
            btnAceptar.setOnClickListener(v -> aceptarConformidad());
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        updateSignerUi();
        updateValidationState(false);
        ensureConformidadData();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (locationCaptureHelper != null) {
            locationCaptureHelper.stop();
        }
        if (requestQueue != null) {
            requestQueue.cancelAll("conformidad_pedido");
            requestQueue.cancelAll("conformidad_pdf");
        }
    }

    private void ensureConformidadData() {
        ConformidadData fromIntent = parseConformidadData(pedidoJson);
        if (fromIntent != null) {
            conformidadData = fromIntent;
            renderConformidad();
            if (hasRenderableConformidad(fromIntent)) {
                return;
            }
        }
        fetchPedido();
    }

    private void fetchPedido() {
        if (referencia.isEmpty()) {
            Toast.makeText(this, "Referencia no disponible", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        try {
            String url = PEDIDO_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&referencia=" + URLEncoder.encode(referencia, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    this::handlePedidoResponse,
                    error -> {
                        String msg = buildVolleyErrorMessage(error, "No se pudo cargar la conformidad");
                        if (conformidadData == null || !hasRenderableConformidad(conformidadData)) {
                            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                            finish();
                        } else {
                            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                        }
                    }
            );
            request.setShouldCache(false);
            request.setTag("conformidad_pedido");
            request.setRetryPolicy(new DefaultRetryPolicy(20000, 1, 1.0f));
            requestQueue.add(request);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo preparar la carga de datos", Toast.LENGTH_LONG).show();
            if (conformidadData == null || !hasRenderableConformidad(conformidadData)) {
                finish();
            }
        }
    }

    private void handlePedidoResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String msg = UiText.sanitizeDbValue(root.optString("message", "No se pudo cargar la conformidad"));
                Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                if (conformidadData == null || !hasRenderableConformidad(conformidadData)) {
                    finish();
                }
                return;
            }
            JSONObject pedido = root.optJSONObject("pedido");
            if (pedido == null) {
                Toast.makeText(this, "Pedido sin datos", Toast.LENGTH_LONG).show();
                if (conformidadData == null || !hasRenderableConformidad(conformidadData)) {
                    finish();
                }
                return;
            }
            pedidoJson = pedido.toString();
            String clientePedido = UiText.sanitizeDbValue(pedido.optString("cliente", ""));
            if (!clientePedido.isEmpty()) {
                cliente = clientePedido;
                UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");
            }
            ConformidadData refreshed = parseConformidadData(pedidoJson);
            if (refreshed != null) {
                conformidadData = refreshed;
                renderConformidad();
            }
        } catch (Exception e) {
            Toast.makeText(this, "Respuesta inválida al cargar la conformidad", Toast.LENGTH_LONG).show();
            if (conformidadData == null || !hasRenderableConformidad(conformidadData)) {
                finish();
            }
        }
    }

    @Nullable
    private ConformidadData parseConformidadData(String pedidoJsonRaw) {
        String raw = UiText.sanitizeDbValue(pedidoJsonRaw);
        if (raw.isEmpty()) {
            return null;
        }
        try {
            JSONObject pedido = new JSONObject(raw);
            JSONObject conformidad = pedido.optJSONObject("conformidad");
            ConformidadData data = new ConformidadData();
            data.referencia = UiText.sanitizeDbValue(pedido.optString("referencia", referencia));
            data.clienteCabecera = UiText.sanitizeDbValue(pedido.optString("cliente", cliente));

            if (conformidad != null) {
                JSONObject clienteJson = conformidad.optJSONObject("cliente");
                if (clienteJson != null) {
                    data.nombre = UiText.sanitizeDbValue(clienteJson.optString("nombre", ""));
                    data.apellidos = UiText.sanitizeDbValue(clienteJson.optString("apellidos", ""));
                    data.dni = UiText.sanitizeDbValue(clienteJson.optString("dni", ""));
                    data.direccion = UiText.sanitizeDbValue(clienteJson.optString("direccion", ""));
                    data.cp = UiText.sanitizeDbValue(clienteJson.optString("cp", ""));
                    data.poblacion = UiText.sanitizeDbValue(clienteJson.optString("poblacion", ""));
                    data.provincia = UiText.sanitizeDbValue(clienteJson.optString("provincia", ""));
                }
                JSONObject instalacionJson = conformidad.optJSONObject("instalacion");
                if (instalacionJson != null) {
                    data.direccionInstalacion = UiText.sanitizeDbValue(instalacionJson.optString("direccion", ""));
                }
            }

            if (data.nombre.isEmpty() && data.apellidos.isEmpty()) {
                JSONObject facturacion = pedido.optJSONObject("facturacion");
                if (facturacion != null) {
                    String nombreFact = UiText.sanitizeDbValue(facturacion.optString("nombre", ""));
                    if (!nombreFact.isEmpty()) {
                        data.nombre = nombreFact;
                    }
                    data.direccion = UiText.sanitizeDbValue(facturacion.optString("direccion", ""));
                    String poblacionFact = UiText.sanitizeDbValue(facturacion.optString("poblacion", ""));
                    if (!poblacionFact.isEmpty()) {
                        String[] parts = poblacionFact.split("-", 2);
                        if (parts.length > 0) {
                            data.cp = UiText.sanitizeDbValue(parts[0]);
                        }
                        if (parts.length > 1) {
                            data.poblacion = UiText.sanitizeDbValue(parts[1]);
                        }
                    }
                }
            }
            if (data.direccionInstalacion.isEmpty()) {
                data.direccionInstalacion = UiText.sanitizeDbValue(pedido.optString("direccion_instalacion", ""));
            }
            if (data.clienteCabecera.isEmpty()) {
                data.clienteCabecera = buildClientFullName(data.nombre, data.apellidos);
            }
            if (data.referencia.isEmpty()) {
                data.referencia = referencia;
            }
            return data;
        } catch (Exception e) {
            return null;
        }
    }

    private boolean hasRenderableConformidad(@Nullable ConformidadData data) {
        if (data == null) {
            return false;
        }
        return !buildClientFullName(data.nombre, data.apellidos).isEmpty()
                && !data.direccionInstalacion.isEmpty();
    }

    private void renderConformidad() {
        if (conformidadData == null) {
            return;
        }
        if (txtDocumento != null) {
            txtDocumento.setText(buildDocumentText(conformidadData));
        }
        if (txtFirmaContexto != null) {
            txtFirmaContexto.setText(
                    "Y para que así conste, y en prueba de conformidad, se firma el presente documento mediante firma manuscrita electrónica en dispositivo digital, quedando registrada la fecha y hora de la firma."
            );
        }
        if (txtCliente != null) {
            String clienteCabecera = conformidadData.clienteCabecera;
            if (clienteCabecera.isEmpty()) {
                clienteCabecera = buildClientFullName(conformidadData.nombre, conformidadData.apellidos);
            }
            UiText.setTextOrPlaceholder(txtCliente, clienteCabecera, "Cliente no disponible");
        }
        updateFirmaPie();
    }

    private String buildDocumentText(ConformidadData data) {
        StringBuilder sb = new StringBuilder();
        sb.append("D./Dña.: ").append(displayLine(buildClientFullName(data.nombre, data.apellidos))).append("\n");
        sb.append("DNI/NIF: ").append(displayLine(data.dni)).append("\n");
        sb.append("Dirección: ").append(displayLine(data.direccion)).append("\n");
        sb.append("CP – Población: ").append(displayLine(buildCpPoblacion(data.cp, data.poblacion))).append("\n");
        sb.append("Provincia: ").append(displayLine(data.provincia)).append("\n");
        sb.append("Referencia del pedido: ").append(displayLine(data.referencia)).append("\n\n");

        sb.append("CLIMAMANIA SALES SPAIN S.L.\n");
        sb.append("CIF: B66040577\n");
        sb.append("C/ Electrónica 14\n");
        sb.append("08110 Montcada i Reixac (Barcelona)\n");
        sb.append("Tel.: 933 282 421\n\n");

        sb.append("Manifiesta mediante la firma del presente documento que CLIMAMANIA SALES SPAIN S.L. ha realizado la instalación en el domicilio situado en: ");
        sb.append(displayLine(data.direccionInstalacion)).append("\n\n");

        sb.append("La persona firmante declara que:\n");
        sb.append("• La instalación ha sido finalizada conforme al presupuesto o encargo previamente aceptado.\n");
        sb.append("• Ha podido revisar la instalación en presencia del personal instalador, comprobando el estado de los equipos y materiales suministrados.\n");
        sb.append("• La instalación se encuentra terminada y correctamente ejecutada, no quedando trabajos pendientes por parte de CLIMAMANIA SALES SPAIN S.L., salvo aquellos que, en su caso, queden reflejados expresamente en el apartado de observaciones.\n");
        sb.append("• Se encuentra conforme con la ubicación de los equipos instalados, el trazado de las canalizaciones, perforaciones, soportes, canaletas y demás elementos necesarios para la instalación.\n");
        sb.append("• Los equipos instalados se encuentran en correcto estado y funcionamiento, o preparados para su puesta en marcha según corresponda al tipo de instalación realizada.\n\n");

        sb.append("La persona firmante declara que ha revisado la instalación en presencia del instalador, no apreciando defectos visibles en el momento de la firma y prestando su conformidad con los trabajos realizados y el resultado final de la instalación.\n\n");
        sb.append("La firma del presente documento implica la aceptación de la instalación realizada, por lo que cualquier reclamación posterior deberá referirse exclusivamente a defectos ocultos o incidencias no apreciables en el momento de la revisión y firma, salvo las que se hagan constar expresamente en el apartado de observaciones.\n\n");
        sb.append("Asimismo, el cliente queda informado de que determinados equipos pueden requerir puesta en marcha, sellado de garantía o intervención del servicio técnico oficial del fabricante.");
        return sb.toString();
    }

    private void onSignerCheckboxChanged(boolean isClienteTitular, boolean isChecked) {
        if (updatingSignerSelection) {
            return;
        }
        updatingSignerSelection = true;
        if (isClienteTitular) {
            if (cbRepresentante != null && isChecked) {
                cbRepresentante.setChecked(false);
            }
        } else {
            if (cbClienteTitular != null && isChecked) {
                cbClienteTitular.setChecked(false);
            }
        }
        updatingSignerSelection = false;
        resetSignatureForSignerChange();
        updateSignerUi();
        updateValidationState(false);
    }

    private void onRepresentativeFieldsChanged() {
        if (isRepresentanteSelected() && signaturePad != null && signaturePad.hasSignature()) {
            signaturePad.clear();
        }
        updateSignerUi();
        updateValidationState(false);
    }

    private void resetSignatureForSignerChange() {
        if (signaturePad != null && signaturePad.hasSignature()) {
            signaturePad.clear();
        }
    }

    private void updateSignerUi() {
        boolean isRepresentante = isRepresentanteSelected();
        if (llRepresentante != null) {
            llRepresentante.setVisibility(isRepresentante ? View.VISIBLE : View.GONE);
        }
        if (txtRepresentanteAviso != null) {
            txtRepresentanteAviso.setVisibility(isRepresentante ? View.VISIBLE : View.GONE);
        }
        updateFirmaPie();
    }

    private void updateFirmaPie() {
        if (txtFirmaPieNombre == null || txtFirmaPieDni == null) {
            return;
        }
        if (isRepresentanteSelected()) {
            String nombre = buildClientFullName(
                    getTrimmedText(editRepresentanteNombre),
                    getTrimmedText(editRepresentanteApellidos)
            );
            String dni = getTrimmedText(editRepresentanteDni);
            txtFirmaPieNombre.setText("D./Dña.: " + displayLine(nombre));
            txtFirmaPieDni.setText("DNI/NIF: " + displayLine(dni));
            return;
        }
        if (isClienteTitularSelected()) {
            String nombre = conformidadData != null
                    ? buildClientFullName(conformidadData.nombre, conformidadData.apellidos)
                    : "";
            String dni = conformidadData != null ? conformidadData.dni : "";
            txtFirmaPieNombre.setText("D./Dña.: " + displayLine(nombre));
            txtFirmaPieDni.setText("DNI/NIF: " + displayLine(dni));
            return;
        }
        txtFirmaPieNombre.setText("D./Dña.: ________________________________");
        txtFirmaPieDni.setText("DNI/NIF: ________________________________");
    }

    private void updateValidationState(boolean showMessages) {
        boolean firmanteValido = isFirmanteValido();
        boolean firmaExistente = signaturePad != null && signaturePad.hasSignature();
        boolean habilitarFirma = firmanteValido;

        if (signaturePad != null) {
            signaturePad.setDrawingEnabled(habilitarFirma);
            signaturePad.setAlpha(habilitarFirma ? 1f : 0.45f);
        }
        if (btnLimpiarFirma != null) {
            btnLimpiarFirma.setEnabled(habilitarFirma && firmaExistente);
        }
        if (btnAceptar != null) {
            btnAceptar.setEnabled(!generatingPdf && firmanteValido && firmaExistente);
        }

        if (showMessages) {
            if (!hasRenderableConformidad(conformidadData)) {
                Toast.makeText(this, "Todavía no se han cargado los datos de conformidad", Toast.LENGTH_SHORT).show();
            } else if (!hasSignerSelection()) {
                Toast.makeText(this, "Debes indicar quién firma", Toast.LENGTH_SHORT).show();
            } else if (isRepresentanteSelected() && !isRepresentanteCompleto()) {
                Toast.makeText(this, "Debes completar nombre, apellidos y DNI del representante", Toast.LENGTH_LONG).show();
            } else if (!firmaExistente) {
                Toast.makeText(this, "Debes recoger la firma manuscrita", Toast.LENGTH_SHORT).show();
            }
        }
    }

    private boolean hasSignerSelection() {
        return isClienteTitularSelected() || isRepresentanteSelected();
    }

    private boolean isFirmanteValido() {
        if (!hasRenderableConformidad(conformidadData)) {
            return false;
        }
        if (isClienteTitularSelected()) {
            return true;
        }
        if (isRepresentanteSelected()) {
            return isRepresentanteCompleto();
        }
        return false;
    }

    private boolean isRepresentanteCompleto() {
        return !getTrimmedText(editRepresentanteNombre).isEmpty()
                && !getTrimmedText(editRepresentanteApellidos).isEmpty()
                && !getTrimmedText(editRepresentanteDni).isEmpty();
    }

    private boolean isClienteTitularSelected() {
        return cbClienteTitular != null && cbClienteTitular.isChecked();
    }

    private boolean isRepresentanteSelected() {
        return cbRepresentante != null && cbRepresentante.isChecked();
    }

    private void aceptarConformidad() {
        updateValidationState(true);
        if (!isFirmanteValido() || signaturePad == null || !signaturePad.hasSignature()) {
            return;
        }
        if (generatingPdf) {
            return;
        }

        if (submissionToken.isEmpty()) {
            submissionToken = UUID.randomUUID().toString();
        }
        setGeneratingState(true, "Obteniendo ubicación...");
        locationCaptureHelper.capture(new EventLocationCaptureHelper.Callback() {
            @Override
            public void onLocationReady(@androidx.annotation.NonNull EventLocationCaptureHelper.CapturedLocation location) {
                try {
                    String firmaBase64 = signaturePad.exportToBase64Png();
                    Map<String, String> payload = buildPdfPayload(location, firmaBase64);
                    setGeneratingState(true, "Generando PDF...");
                    generarPdfWithFallback(payload, 0, "");
                } catch (Exception e) {
                    setGeneratingState(false, null);
                    Toast.makeText(
                            ConformeClienteConformidadActivity.this,
                            "No se pudo capturar la firma",
                            Toast.LENGTH_SHORT
                    ).show();
                }
            }

            @Override
            public void onLocationError(@androidx.annotation.NonNull String message) {
                setGeneratingState(false, null);
                Toast.makeText(ConformeClienteConformidadActivity.this, message, Toast.LENGTH_LONG).show();
            }
        });
    }

    private Map<String, String> buildPdfPayload(
            EventLocationCaptureHelper.CapturedLocation location,
            String firmaBase64
    ) {
        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("referencia", referencia);
        params.put("requiere_boe", String.valueOf(requiereBoe));
        params.put("revision_boe_guardada", String.valueOf(revisionBoeGuardada));
        params.put("observaciones_conformidad", getTrimmedText(editObservaciones));
        params.put("tipo_firmante", isRepresentanteSelected() ? "representante_autorizado" : "cliente_titular");
        params.put("firmante_nombre",
                isRepresentanteSelected() ? getTrimmedText(editRepresentanteNombre)
                        : (conformidadData != null ? UiText.sanitizeDbValue(conformidadData.nombre) : ""));
        params.put("firmante_apellidos",
                isRepresentanteSelected() ? getTrimmedText(editRepresentanteApellidos)
                        : (conformidadData != null ? UiText.sanitizeDbValue(conformidadData.apellidos) : ""));
        params.put("firmante_dni",
                isRepresentanteSelected() ? getTrimmedText(editRepresentanteDni)
                        : (conformidadData != null ? UiText.sanitizeDbValue(conformidadData.dni) : ""));
        params.put("firma_base64_png", firmaBase64);
        params.put("latitud", location.latitudeParam());
        params.put("longitud", location.longitudeParam());
        params.put("usuario", resolveUsuarioActual());
        params.put("submission_token", submissionToken);
        return params;
    }

    private void generarPdfWithFallback(Map<String, String> payload, int index, String lastError) {
        if (index >= GENERATE_PDF_URLS.length) {
            setGeneratingState(false, null);
            String msg = UiText.sanitizeDbValue(lastError);
            if (msg.isEmpty()) {
                msg = "No se pudo generar el PDF de conformidad";
            }
            Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
            return;
        }

        StringRequest request = new StringRequest(
                Request.Method.POST,
                GENERATE_PDF_URLS[index],
                response -> {
                    String parseError = handleGeneratePdfResponse(response);
                    if (parseError != null) {
                        generarPdfWithFallback(payload, index + 1, parseError);
                    }
                },
                error -> generarPdfWithFallback(
                        payload,
                        index + 1,
                        buildVolleyErrorMessage(error, "No se pudo generar el PDF de conformidad")
                )
        ) {
            @Override
            protected Map<String, String> getParams() {
                return payload;
            }
        };
        request.setShouldCache(false);
        request.setTag("conformidad_pdf");
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        requestQueue.add(request);
    }

    @Nullable
    private String handleGeneratePdfResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                return UiText.sanitizeDbValue(root.optString("message", "No se pudo generar el PDF de conformidad"));
            }

            setGeneratingState(false, null);
            Intent result = new Intent();
            result.putExtra("referencia", referencia);
            result.putExtra("cliente", cliente);
            if (!pedidoJson.isEmpty()) {
                result.putExtra("pedido_json", pedidoJson);
            }
            result.putExtra("requiere_boe", requiereBoe);
            result.putExtra("revision_boe_guardada", revisionBoeGuardada);
            result.putExtra("observaciones_conformidad", getTrimmedText(editObservaciones));

            String tipoFirmante;
            String firmanteNombre;
            String firmanteApellidos;
            String firmanteDni;
            if (isRepresentanteSelected()) {
                tipoFirmante = "representante_autorizado";
                firmanteNombre = getTrimmedText(editRepresentanteNombre);
                firmanteApellidos = getTrimmedText(editRepresentanteApellidos);
                firmanteDni = getTrimmedText(editRepresentanteDni);
            } else {
                tipoFirmante = "cliente_titular";
                firmanteNombre = conformidadData != null ? UiText.sanitizeDbValue(conformidadData.nombre) : "";
                firmanteApellidos = conformidadData != null ? UiText.sanitizeDbValue(conformidadData.apellidos) : "";
                firmanteDni = conformidadData != null ? UiText.sanitizeDbValue(conformidadData.dni) : "";
            }
            result.putExtra("tipo_firmante", tipoFirmante);
            result.putExtra("firmante_nombre", firmanteNombre);
            result.putExtra("firmante_apellidos", firmanteApellidos);
            result.putExtra("firmante_dni", firmanteDni);
            result.putExtra("firma_base64_png", signaturePad != null ? signaturePad.exportToBase64Png() : "");
            result.putExtra("pdf", UiText.sanitizeDbValue(root.optString("pdf", "")));
            result.putExtra("pdf_url", UiText.sanitizeDbValue(root.optString("pdf_url", "")));
            result.putExtra("submission_token", submissionToken);

            setResult(Activity.RESULT_OK, result);
            finish();
            return null;
        } catch (Exception e) {
            return "Respuesta inválida del servidor";
        }
    }

    private void setGeneratingState(boolean value, @Nullable String buttonText) {
        generatingPdf = value;
        if (btnAceptar != null) {
            if (buttonText != null && !buttonText.trim().isEmpty()) {
                btnAceptar.setText(buttonText);
            } else {
                btnAceptar.setText("Aceptar");
            }
        }
        updateValidationState(false);
    }

    private String buildVolleyErrorMessage(com.android.volley.VolleyError error, String fallback) {
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

    private String getTrimmedText(@Nullable EditText editText) {
        if (editText == null || editText.getText() == null) {
            return "";
        }
        return UiText.sanitizeDbValue(editText.getText().toString());
    }

    private String buildClientFullName(String nombre, String apellidos) {
        String cleanNombre = UiText.sanitizeDbValue(nombre);
        String cleanApellidos = UiText.sanitizeDbValue(apellidos);
        String fullName = (cleanNombre + " " + cleanApellidos).trim();
        return UiText.sanitizeDbValue(fullName);
    }

    private String buildCpPoblacion(String cp, String poblacion) {
        String cleanCp = UiText.sanitizeDbValue(cp);
        String cleanPoblacion = UiText.sanitizeDbValue(poblacion);
        if (cleanCp.isEmpty()) {
            return cleanPoblacion;
        }
        if (cleanPoblacion.isEmpty()) {
            return cleanCp;
        }
        return cleanCp + " - " + cleanPoblacion;
    }

    private String displayLine(String value) {
        String clean = UiText.sanitizeDbValue(value);
        return clean.isEmpty() ? "__________________________________" : clean;
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

    private abstract static class SimpleTextWatcher implements TextWatcher {
        @Override
        public void beforeTextChanged(CharSequence s, int start, int count, int after) {
        }

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {
        }
    }

    private static final class ConformidadData {
        String referencia = "";
        String clienteCabecera = "";
        String nombre = "";
        String apellidos = "";
        String dni = "";
        String direccion = "";
        String cp = "";
        String poblacion = "";
        String provincia = "";
        String direccionInstalacion = "";
    }
}
