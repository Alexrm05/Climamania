package com.example.climamaniaapp;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.TextView;

import androidx.annotation.Nullable;

public class ConformeClienteBoeDecisionActivity extends BaseActivity {

    private String referencia;
    private String cliente;
    private String pedidoJson;
    private Boolean requiereBoeSeleccionado;

    private TextView txtReferencia;
    private TextView txtCliente;
    private RadioGroup rgBoeDecision;
    private RadioButton rbBoeSi;
    private RadioButton rbBoeNo;
    private Button btnContinuar;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(
                R.layout.content_conforme_cliente_boe_decision,
                contentFrame,
                true
        );

        setupBottomBar();

        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));
        pedidoJson = UiText.sanitizeDbValue(getIntent().getStringExtra("pedido_json"));
        if (getIntent().hasExtra("requiere_boe_preseleccionado")) {
            requiereBoeSeleccionado = getIntent().getBooleanExtra("requiere_boe_preseleccionado", false);
        }

        txtReferencia = content.findViewById(R.id.txtConformeBoeReferencia);
        txtCliente = content.findViewById(R.id.txtConformeBoeCliente);
        rgBoeDecision = content.findViewById(R.id.rgConformeBoeDecision);
        rbBoeSi = content.findViewById(R.id.rbConformeBoeSi);
        rbBoeNo = content.findViewById(R.id.rbConformeBoeNo);
        btnContinuar = content.findViewById(R.id.btnConformeBoeContinuar);
        Button btnVolver = content.findViewById(R.id.btnConformeBoeVolver);

        UiText.setTextOrPlaceholder(txtReferencia, referencia, "Referencia no disponible");
        UiText.setTextOrPlaceholder(txtCliente, cliente, "Cliente no disponible");

        if (requiereBoeSeleccionado != null) {
            if (requiereBoeSeleccionado) {
                rbBoeSi.setChecked(true);
            } else {
                rbBoeNo.setChecked(true);
            }
        }

        if (rgBoeDecision != null) {
            rgBoeDecision.setOnCheckedChangeListener((group, checkedId) -> {
                if (checkedId == R.id.rbConformeBoeSi) {
                    requiereBoeSeleccionado = true;
                } else if (checkedId == R.id.rbConformeBoeNo) {
                    requiereBoeSeleccionado = false;
                } else {
                    requiereBoeSeleccionado = null;
                }
                updateContinuarState();
            });
        }

        if (btnContinuar != null) {
            btnContinuar.setOnClickListener(v -> devolverResultado());
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        updateContinuarState();
    }

    private void updateContinuarState() {
        if (btnContinuar != null) {
            btnContinuar.setEnabled(requiereBoeSeleccionado != null);
        }
    }

    private void devolverResultado() {
        if (requiereBoeSeleccionado == null) {
            android.widget.Toast.makeText(this, "Debes indicar si requiere BOE", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        Intent result = new Intent();
        result.putExtra("referencia", referencia);
        result.putExtra("cliente", cliente);
        if (pedidoJson != null && !pedidoJson.trim().isEmpty()) {
            result.putExtra("pedido_json", pedidoJson);
        }
        result.putExtra("requiere_boe", requiereBoeSeleccionado);
        setResult(Activity.RESULT_OK, result);
        finish();
    }
}
