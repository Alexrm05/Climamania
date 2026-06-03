package com.example.climamaniaapp;

import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.VideoView;
import android.widget.MediaController;

import androidx.annotation.Nullable;

public class VideoPlayerActivity extends BaseActivity {

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_video_player, contentFrame, true);

        setupBottomBar();

        TextView txtTitulo = content.findViewById(R.id.txtVideoTitulo);
        TextView txtLoading = content.findViewById(R.id.txtVideoLoading);
        VideoView videoView = content.findViewById(R.id.videoView);
        View btnVolver = content.findViewById(R.id.btnVideoVolver);

        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        java.util.ArrayList<String> urls = getIntent().getStringArrayListExtra("video_urls");
        String singleUrl = UiText.sanitizeDbValue(getIntent().getStringExtra("video_url"));
        if ((urls == null || urls.isEmpty()) && singleUrl.isEmpty()) {
            android.widget.Toast.makeText(this, "Video no disponible", android.widget.Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        if (txtTitulo != null) {
            txtTitulo.setText("Reproductor de video");
        }

        MediaController controller = new MediaController(this);
        controller.setAnchorView(videoView);
        videoView.setMediaController(controller);

        final java.util.List<String> sources = new java.util.ArrayList<>();
        if (urls != null) {
            for (String u : urls) {
                String clean = UiText.sanitizeDbValue(u);
                if (!clean.isEmpty()) sources.add(clean);
            }
        }
        if (sources.isEmpty() && !singleUrl.isEmpty()) {
            sources.add(singleUrl);
        }

        final int[] index = new int[] { 0 };

        Runnable playNext = new Runnable() {
            @Override
            public void run() {
                if (index[0] >= sources.size()) {
                    if (txtLoading != null) {
                        txtLoading.setText("No se pudo reproducir el video");
                    }
                    return;
                }
                String nextUrl = sources.get(index[0]);
                if (txtLoading != null) {
                    txtLoading.setVisibility(View.VISIBLE);
                    txtLoading.setText("Cargando...");
                }
                videoView.setVideoURI(Uri.parse(nextUrl));
                videoView.requestFocus();
                videoView.start();
            }
        };

        videoView.setOnPreparedListener(mp -> {
            if (txtLoading != null) {
                txtLoading.setVisibility(View.GONE);
            }
        });
        videoView.setOnErrorListener((mp, what, extra) -> {
            index[0] += 1;
            playNext.run();
            return true;
        });

        playNext.run();
    }
}
