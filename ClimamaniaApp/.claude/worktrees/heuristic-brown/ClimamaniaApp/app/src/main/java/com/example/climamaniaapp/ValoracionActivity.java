package com.example.climamaniaapp;

import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.Nullable;

public class ValoracionActivity extends BaseActivity {

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_valoracion, contentFrame, true);

        setupBottomBar();

        View btnVolver = content.findViewById(R.id.btnValoracionVolver);
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
    }
}
