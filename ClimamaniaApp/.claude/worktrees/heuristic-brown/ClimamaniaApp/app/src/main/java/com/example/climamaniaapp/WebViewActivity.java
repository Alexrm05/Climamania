package com.example.climamaniaapp;

import android.content.Intent;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.view.View;

public class WebViewActivity extends BaseActivity {

    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        // Inyectar el layout específico dentro de activity_base
        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View webContent = getLayoutInflater().inflate(R.layout.content_webview, contentFrame, false);
        contentFrame.addView(webContent);

        // Activar barra inferior
        setupBottomBar();

        // Configurar el WebView
        webView = webContent.findViewById(R.id.webView);
        WebSettings webSettings = webView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setSupportZoom(false);
        webSettings.setBuiltInZoomControls(false);
        webSettings.setDisplayZoomControls(false);
        webSettings.setUseWideViewPort(true);
        webSettings.setLoadWithOverviewMode(true);

        // Abrir enlaces dentro del WebView (no en navegador externo)
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                // Nuevo API: manejar la petición y cargar la URL
                view.loadUrl(request.getUrl().toString());
                return true;
            }

            @SuppressWarnings("deprecation")
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                // Fallback para versiones antiguas
                view.loadUrl(url);
                return true;
            }
        });

        // URL objetivo: si viene en el Intent la usamos, si no, la web general
        Intent intent = getIntent();
        String targetUrl = intent != null
                ? intent.getStringExtra("target_url")
                : null;
        if (targetUrl == null || targetUrl.trim().isEmpty()) {
            targetUrl = "https://www.climamania.com";
        }

        webView.loadUrl(targetUrl);
    }
}
