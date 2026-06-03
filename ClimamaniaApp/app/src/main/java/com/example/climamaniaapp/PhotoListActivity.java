package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.net.Uri;
import android.os.Bundle;
import android.Manifest;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.FileProvider;
import androidx.core.content.ContextCompat;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.Response;
import com.android.volley.VolleyError;
import com.android.volley.DefaultRetryPolicy;
import com.android.volley.toolbox.HttpHeaderParser;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import androidx.exifinterface.media.ExifInterface;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.net.URLEncoder;
import android.content.pm.PackageManager;
import java.nio.charset.StandardCharsets;

public class PhotoListActivity extends BaseActivity {

    private static final String PHOTO_BASE_URL = "https://clminstal.es/";
    private static final String PHOTO_ALT_BASE_URL = "https://app.clminstal.es/";
    private static final String PHOTO_API_URL = "https://app.clminstal.es/api/get_foto.php";
    private static final String PEDIDO_URL = "https://app.clminstal.es/api/get_pedido.php";
    private static final String UPLOAD_URL = "https://app.clminstal.es/api/upload_foto.php";
    private static final String API_KEY = "TEST123";

    private TextView txtTitulo;
    private TextView txtSubtitulo;
    private TextView txtEmpty;
    private LinearLayout listContainer;
    private RequestQueue imageQueue;
    private Button btnSubir;

    private ActivityResultLauncher<Uri> cameraLauncher;
    private ActivityResultLauncher<String> galleryLauncher;
    private ActivityResultLauncher<String> videoLauncher;
    private ActivityResultLauncher<String> cameraPermissionLauncher;
    private Uri tempPhotoUri;
    private File tempPhotoFile;

    private String referencia;
    private String categoria;
    private String claveUpload;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_photo_list, contentFrame, true);

        setupBottomBar();

        txtTitulo = content.findViewById(R.id.txtFotosTitulo);
        txtSubtitulo = content.findViewById(R.id.txtFotosSubtitulo);
        txtEmpty = content.findViewById(R.id.txtFotosEmpty);
        listContainer = content.findViewById(R.id.llFotosList);
        btnSubir = content.findViewById(R.id.btnFotosSubir);
        imageQueue = Volley.newRequestQueue(this);
        Button btnVolver = content.findViewById(R.id.btnFotosVolver);

        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }

        String titulo = UiText.sanitizeDbValue(getIntent().getStringExtra("titulo"));
        referencia = UiText.sanitizeDbValue(getIntent().getStringExtra("referencia"));
        categoria = UiText.sanitizeDbValue(getIntent().getStringExtra("categoria"));
        claveUpload = UiText.sanitizeDbValue(getIntent().getStringExtra("clave"));
        String fotosJson = UiText.sanitizeDbValue(getIntent().getStringExtra("fotos_json"));

        txtTitulo.setText(titulo.isEmpty() ? "Fotografías" : titulo);
        if (referencia.isEmpty()) {
            txtSubtitulo.setText(UiText.placeholderSpan("Referencia no disponible"));
        } else {
            txtSubtitulo.setText("Referencia " + referencia);
        }

        setupUploadLaunchers();

        if (btnSubir != null) {
            if (claveUpload == null || claveUpload.trim().isEmpty()) {
                btnSubir.setVisibility(View.GONE);
            } else {
                btnSubir.setOnClickListener(v -> mostrarOpcionesSubida());
            }
        }

        List<String> fotos = parseFotos(fotosJson);
        renderFotos(fotos);

        if (!referencia.isEmpty() && !categoria.isEmpty()) {
            cargarFotosDesdeApi();
        }
    }

    private void setupUploadLaunchers() {
        cameraPermissionLauncher = registerForActivityResult(
                new ActivityResultContracts.RequestPermission(),
                granted -> {
                    if (granted) {
                        abrirCamara();
                    } else {
                        android.widget.Toast.makeText(this,
                                "Permiso de cámara denegado",
                                android.widget.Toast.LENGTH_SHORT).show();
                    }
                });

        cameraLauncher = registerForActivityResult(
                new ActivityResultContracts.TakePicture(),
                success -> {
                    if (success && tempPhotoFile != null) {
                        uploadFile(tempPhotoFile, "image/jpeg");
                    }
                });

        galleryLauncher = registerForActivityResult(
                new ActivityResultContracts.GetContent(),
                uri -> {
                    if (uri != null) {
                        uploadFromUri(uri);
                    }
                });

        videoLauncher = registerForActivityResult(
                new ActivityResultContracts.GetContent(),
                uri -> {
                    if (uri != null) {
                        uploadFromUri(uri);
                    }
                });
    }

    private void mostrarOpcionesSubida() {
        String[] items = { "Cámara (foto)", "Galería (foto)", "Galería (video)" };
        new AlertDialog.Builder(this)
                .setTitle("Subir archivo")
                .setItems(items, (dialog, which) -> {
                    if (which == 0) {
                        abrirCamara();
                    } else if (which == 1) {
                        abrirGaleria();
                    } else {
                        abrirGaleriaVideo();
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void abrirCamara() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (cameraPermissionLauncher != null) {
                cameraPermissionLauncher.launch(Manifest.permission.CAMERA);
            } else {
                android.widget.Toast.makeText(this,
                        "Permiso de cámara no disponible",
                        android.widget.Toast.LENGTH_SHORT).show();
            }
            return;
        }

        try {
            File cacheDir = new File(getCacheDir(), "images");
            if (!cacheDir.exists()) {
                cacheDir.mkdirs();
            }
            tempPhotoFile = File.createTempFile("foto_", ".jpg", cacheDir);
            tempPhotoUri = FileProvider.getUriForFile(
                    this,
                    getPackageName() + ".fileprovider",
                    tempPhotoFile);
            cameraLauncher.launch(tempPhotoUri);
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "No se pudo abrir la cámara", android.widget.Toast.LENGTH_SHORT).show();
        }
    }

    private void abrirGaleria() {
        galleryLauncher.launch("image/*");
    }

    private void abrirGaleriaVideo() {
        if (videoLauncher != null) {
            videoLauncher.launch("video/*");
        }
    }

    private void uploadFile(File file, String mime) {
        if (file == null || !file.exists()) {
            android.widget.Toast.makeText(this, "Archivo no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            byte[] data = readBytes(new FileInputStream(file));
            uploadBytes(data, file.getName(), mime);
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "No se pudo leer la foto", android.widget.Toast.LENGTH_SHORT).show();
        }
    }

    private void uploadFromUri(Uri uri) {
        try {
            InputStream in = getContentResolver().openInputStream(uri);
            if (in == null) {
                android.widget.Toast.makeText(this, "No se pudo leer el archivo", android.widget.Toast.LENGTH_SHORT)
                        .show();
                return;
            }
            byte[] data = readBytes(in);
            String mime = resolveMimeType(uri);
            String name = resolveDisplayName(uri);
            String safeName = ensureFileName(name, mime);
            uploadBytes(data, safeName, mime);
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "No se pudo leer el archivo", android.widget.Toast.LENGTH_SHORT).show();
        }
    }

    private void uploadBytes(byte[] data, String filename, String mime) {
        if (referencia == null || referencia.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Referencia no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }
        if (claveUpload == null || claveUpload.trim().isEmpty()) {
            android.widget.Toast.makeText(this, "Sección no disponible", android.widget.Toast.LENGTH_SHORT).show();
            return;
        }

        android.widget.Toast.makeText(this, "Subiendo...", android.widget.Toast.LENGTH_SHORT).show();

        RequestQueue queue = Volley.newRequestQueue(this);
        boolean imageMime = isImageMime(mime);
        byte[] payload = imageMime ? compressImageIfNeeded(data) : data;
        String finalName = imageMime ? ensureJpegName(filename) : ensureFileName(filename, mime);
        String finalMime = imageMime ? "image/jpeg" : mime;
        MultipartRequest request = new MultipartRequest(
                UPLOAD_URL,
                response -> {
                    try {
                        JSONObject root = new JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            android.widget.Toast.makeText(this,
                                    root.optString("message", "No se pudo subir"),
                                    android.widget.Toast.LENGTH_LONG).show();
                            return;
                        }
                        android.widget.Toast.makeText(this, "Archivo subido", android.widget.Toast.LENGTH_SHORT).show();
                        cargarFotosDesdeApi();
                    } catch (JSONException e) {
                        android.widget.Toast.makeText(this, "Respuesta inválida", android.widget.Toast.LENGTH_SHORT)
                                .show();
                    }
                },
                error -> android.widget.Toast.makeText(this,
                        buildVolleyErrorMessage(error, "Error de conexión al subir"),
                        android.widget.Toast.LENGTH_LONG).show(),
                buildUploadParams(),
                "archivo",
                finalName,
                finalMime,
                payload);
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        request.setShouldCache(false);
        queue.add(request);
    }

    private byte[] compressImageIfNeeded(byte[] data) {
        if (data == null || data.length == 0)
            return data;
        try {
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            BitmapFactory.decodeByteArray(data, 0, data.length, bounds);
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0)
                return data;

            int maxDim = 1600;
            int sampleSize = 1;
            while ((bounds.outWidth / sampleSize) > maxDim
                    || (bounds.outHeight / sampleSize) > maxDim) {
                sampleSize *= 2;
            }

            BitmapFactory.Options opts = new BitmapFactory.Options();
            opts.inSampleSize = Math.max(1, sampleSize);
            opts.inPreferredConfig = Bitmap.Config.RGB_565;
            Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length, opts);
            if (bitmap == null)
                return data;

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out);
            bitmap.recycle();
            byte[] compressed = out.toByteArray();
            return compressed.length > 0 ? compressed : data;
        } catch (Exception e) {
            return data;
        }
    }

    private String ensureJpegName(String filename) {
        if (filename == null || filename.trim().isEmpty())
            return "foto.jpg";
        String lower = filename.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg"))
            return filename;
        int dot = filename.lastIndexOf('.');
        if (dot > 0)
            return filename.substring(0, dot) + ".jpg";
        return filename + ".jpg";
    }

    private String buildVolleyErrorMessage(VolleyError error, String fallback) {
        if (error == null || error.networkResponse == null || error.networkResponse.data == null) {
            return fallback;
        }
        String body = new String(error.networkResponse.data, StandardCharsets.UTF_8).trim();
        if (body.isEmpty())
            return fallback;
        return body;
    }

    private Map<String, String> buildUploadParams() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String usuario = prefs.getString("nombre", "");
        if (usuario == null || usuario.trim().isEmpty()) {
            usuario = prefs.getString("usuario", "Instalador");
        }

        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("referencia", referencia);
        params.put("clave", claveUpload);
        params.put("usuario", usuario);
        return params;
    }

    private void cargarFotosDesdeApi() {
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
                                return;
                            }
                            JSONObject pedido = root.optJSONObject("pedido");
                            if (pedido == null)
                                return;
                            JSONObject fotos = pedido.optJSONObject("fotografias");
                            JSONArray arr = fotos != null ? fotos.optJSONArray(categoria) : null;
                            renderFotos(parseFotos(arr != null ? arr.toString() : ""));
                        } catch (JSONException ignored) {
                        }
                    },
                    error -> {
                    });
            queue.add(request);
        } catch (Exception ignored) {
        }
    }

    private void renderFotos(List<String> fotos) {
        listContainer.removeAllViews();
        if (fotos.isEmpty()) {
            txtEmpty.setVisibility(View.VISIBLE);
            listContainer.setVisibility(View.GONE);
        } else {
            txtEmpty.setVisibility(View.GONE);
            listContainer.setVisibility(View.VISIBLE);
            for (String foto : fotos) {
                addFotoRow(foto);
            }
        }
    }

    private void addFotoRow(String fotoPath) {
        if (shouldRenderAsFile(fotoPath)) {
            addFileRow(fotoPath);
        } else {
            addImageRow(fotoPath);
        }
    }

    private void addImageRow(String fotoPath) {
        List<String> urls = buildPhotoCandidates(fotoPath);
        String primaryUrl = urls.isEmpty() ? "" : urls.get(0);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackgroundResource(R.drawable.bg_detail_card);
        card.setPadding(dp(12), dp(12), dp(12), dp(12));

        FrameLayout frame = new FrameLayout(this);
        frame.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        frame.setMinimumHeight(dp(200));

        ImageView image = new ImageView(this);
        image.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        image.setScaleType(ImageView.ScaleType.FIT_CENTER);
        image.setAdjustViewBounds(true);
        image.setMinimumHeight(dp(200));
        image.setBackgroundColor(0xFFF0F0F0);

        TextView loading = new TextView(this);
        loading.setText("Cargando...");
        loading.setTextColor(0xFF757575);
        loading.setTextSize(13f);
        loading.setGravity(Gravity.CENTER);

        frame.addView(image);
        frame.addView(loading);
        card.addView(frame);

        TextView caption = new TextView(this);
        caption.setText(extractFileName(fotoPath));
        caption.setTextColor(0xFF212121);
        caption.setTextSize(12f);
        caption.setPadding(0, dp(8), 0, 0);
        card.addView(caption);

        final String[] resolved = new String[] { primaryUrl };
        card.setOnClickListener(v -> openWeb(resolved[0]));
        listContainer.addView(card);

        View spacer = new View(this);
        spacer.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(10)));
        listContainer.addView(spacer);

        int maxWidth = getResources().getDisplayMetrics().widthPixels;
        int maxHeight = dp(800);
        loadImageCandidates(urls, 0, image, loading, resolved, maxWidth, maxHeight);
    }

    private void addFileRow(String fotoPath) {
        List<String> urls = buildPhotoCandidates(fotoPath);
        String primaryUrl = urls.isEmpty() ? "" : urls.get(0);
        boolean isVideo = isVideoExtension(fotoPath != null ? fotoPath.toLowerCase(Locale.ROOT) : "");

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setBackgroundResource(R.drawable.bg_detail_card);
        row.setPadding(dp(12), dp(10), dp(12), dp(10));

        TextView name = new TextView(this);
        name.setText(extractFileName(fotoPath));
        name.setTextColor(0xFF212121);
        name.setTextSize(14f);
        name.setLayoutParams(new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView action = new TextView(this);
        action.setText(isVideo ? "Ver video" : "Abrir");
        action.setTextColor(0xFF212121);
        action.setTextSize(12f);
        action.setBackgroundResource(R.drawable.bg_chip_light);
        action.setPadding(dp(10), dp(4), dp(10), dp(4));

        row.addView(name);
        row.addView(action);

        row.setOnClickListener(v -> openMedia(urls, primaryUrl, isVideo));
        listContainer.addView(row);

        View spacer = new View(this);
        spacer.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(10)));
        listContainer.addView(spacer);
    }

    private List<String> parseFotos(String fotosJson) {
        List<String> fotos = new ArrayList<>();
        if (fotosJson == null || fotosJson.trim().isEmpty())
            return fotos;
        try {
            JSONArray arr = new JSONArray(fotosJson);
            for (int i = 0; i < arr.length(); i++) {
                String item = UiText.sanitizeDbValue(arr.optString(i, ""));
                if (item.isEmpty())
                    continue;
                fotos.add(item);
            }
        } catch (JSONException ignored) {
        }
        return fotos;
    }

    private String buildPhotoUrl(String path) {
        if (path == null)
            return "";
        String trimmed = path.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            return trimmed;
        }
        if (trimmed.startsWith("/")) {
            return PHOTO_BASE_URL + trimmed.substring(1);
        }
        return PHOTO_BASE_URL + trimmed;
    }

    private List<String> buildPhotoCandidates(String path) {
        List<String> urls = new ArrayList<>();
        if (path == null)
            return urls;
        String trimmed = path.trim();
        if (trimmed.isEmpty())
            return urls;

        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            urls.add(trimmed);
        } else {
            try {
                String encoded = URLEncoder.encode(trimmed, "UTF-8");
                urls.add(PHOTO_API_URL + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                        + "&doc=" + encoded);
            } catch (Exception ignored) {
            }
            urls.add(normalizeBase(PHOTO_BASE_URL) + normalizePath(trimmed));
            urls.add(normalizeBase(PHOTO_ALT_BASE_URL) + normalizePath(trimmed));
        }

        List<String> expanded = new ArrayList<>();
        for (String url : urls) {
            expanded.add(url);
            if (url.startsWith("https://")) {
                expanded.add("http://" + url.substring("https://".length()));
            }
        }

        return expanded;
    }

    private String extractFileName(String path) {
        if (path == null || path.trim().isEmpty())
            return "Archivo";
        String trimmed = path.trim();
        int idx = trimmed.lastIndexOf('/');
        return idx >= 0 ? trimmed.substring(idx + 1) : trimmed;
    }

    private boolean isImageFile(String path) {
        if (path == null)
            return false;
        String trimmed = path.trim();
        int q = trimmed.indexOf('?');
        if (q >= 0)
            trimmed = trimmed.substring(0, q);
        String lower = trimmed.toLowerCase(Locale.ROOT);
        return lower.endsWith(".jpg")
                || lower.endsWith(".jpeg")
                || lower.endsWith(".png")
                || lower.endsWith(".gif")
                || lower.endsWith(".webp")
                || lower.endsWith(".heic")
                || lower.endsWith(".heif");
    }

    private boolean shouldRenderAsFile(String path) {
        if (isDocumentCategory())
            return true;
        if (path == null)
            return false;
        String trimmed = path.trim();
        int q = trimmed.indexOf('?');
        if (q >= 0)
            trimmed = trimmed.substring(0, q);
        String lower = trimmed.toLowerCase(Locale.ROOT);
        if (isVideoExtension(lower))
            return true;
        if (lower.endsWith(".pdf"))
            return true;
        if (lower.endsWith(".doc") || lower.endsWith(".docx"))
            return true;
        if (lower.endsWith(".xls") || lower.endsWith(".xlsx"))
            return true;
        return false;
    }

    private boolean isVideoExtension(String lowerPath) {
        if (lowerPath == null)
            return false;
        return lowerPath.endsWith(".mp4")
                || lowerPath.endsWith(".mov")
                || lowerPath.endsWith(".m4v")
                || lowerPath.endsWith(".3gp")
                || lowerPath.endsWith(".webm")
                || lowerPath.endsWith(".avi")
                || lowerPath.endsWith(".mkv");
    }

    private boolean isDocumentCategory() {
        if (categoria == null)
            return false;
        String lower = categoria.trim().toLowerCase(Locale.ROOT);
        return lower.equals("boe") || lower.equals("documentos");
    }

    private void openWeb(String url) {
        Intent intent = new Intent(this, WebViewActivity.class);
        intent.putExtra("target_url", url);
        startActivity(intent);
    }

    private void openMedia(List<String> urls, String fallbackUrl, boolean isVideo) {
        String url = fallbackUrl;
        if ((url == null || url.trim().isEmpty()) && urls != null && !urls.isEmpty()) {
            url = urls.get(0);
        }
        if (url == null || url.trim().isEmpty())
            return;
        if (isVideo) {
            Intent intent = new Intent(this, VideoPlayerActivity.class);
            if (urls != null && !urls.isEmpty()) {
                intent.putStringArrayListExtra("video_urls", new ArrayList<>(urls));
            } else {
                intent.putExtra("video_url", url);
            }
            startActivity(intent);
            return;
        }
        openWeb(url);
    }

    private String resolveMimeType(Uri uri) {
        if (uri == null)
            return "application/octet-stream";
        String mime = getContentResolver().getType(uri);
        if (mime != null && !mime.trim().isEmpty()) {
            return mime;
        }
        String name = resolveDisplayName(uri);
        String lower = name != null ? name.toLowerCase(Locale.ROOT) : "";
        if (lower.endsWith(".mp4"))
            return "video/mp4";
        if (lower.endsWith(".mov"))
            return "video/quicktime";
        if (lower.endsWith(".m4v"))
            return "video/x-m4v";
        if (lower.endsWith(".3gp"))
            return "video/3gpp";
        if (lower.endsWith(".webm"))
            return "video/webm";
        if (lower.endsWith(".avi"))
            return "video/x-msvideo";
        if (lower.endsWith(".mkv"))
            return "video/x-matroska";
        if (lower.endsWith(".png"))
            return "image/png";
        if (lower.endsWith(".gif"))
            return "image/gif";
        if (lower.endsWith(".webp"))
            return "image/webp";
        if (lower.endsWith(".heic"))
            return "image/heic";
        if (lower.endsWith(".heif"))
            return "image/heif";
        return "image/jpeg";
    }

    private String resolveDisplayName(Uri uri) {
        if (uri == null)
            return "";
        try (android.database.Cursor cursor = getContentResolver().query(
                uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME);
                if (idx >= 0) {
                    String name = cursor.getString(idx);
                    return name != null ? name : "";
                }
            }
        } catch (Exception ignored) {
        }
        return "";
    }

    private boolean isImageMime(String mime) {
        return mime != null && mime.toLowerCase(Locale.ROOT).startsWith("image/");
    }

    private String ensureFileName(String filename, String mime) {
        String clean = filename == null ? "" : filename.trim();
        if (clean.isEmpty()) {
            return defaultNameForMime(mime);
        }
        int dot = clean.lastIndexOf('.');
        if (dot > 0 && dot < clean.length() - 1) {
            return clean;
        }
        String ext = extensionForMime(mime);
        return ext.isEmpty() ? clean : clean + "." + ext;
    }

    private String defaultNameForMime(String mime) {
        String ext = extensionForMime(mime);
        if (ext.isEmpty()) {
            return "archivo";
        }
        return "archivo." + ext;
    }

    private String extensionForMime(String mime) {
        String lower = mime == null ? "" : mime.toLowerCase(Locale.ROOT);
        if (lower.contains("video/mp4"))
            return "mp4";
        if (lower.contains("video/quicktime"))
            return "mov";
        if (lower.contains("video/x-m4v"))
            return "m4v";
        if (lower.contains("video/3gpp"))
            return "3gp";
        if (lower.contains("video/webm"))
            return "webm";
        if (lower.contains("video/x-msvideo"))
            return "avi";
        if (lower.contains("video/x-matroska"))
            return "mkv";
        if (lower.contains("image/png"))
            return "png";
        if (lower.contains("image/gif"))
            return "gif";
        if (lower.contains("image/webp"))
            return "webp";
        if (lower.contains("image/heic"))
            return "heic";
        if (lower.contains("image/heif"))
            return "heif";
        if (lower.contains("image/jpeg") || lower.contains("image/jpg"))
            return "jpg";
        return "";
    }

    private void loadImageCandidates(
            List<String> urls,
            int index,
            ImageView imageView,
            TextView loadingView,
            String[] resolved,
            int maxWidth,
            int maxHeight) {
        if (urls == null || index >= urls.size()) {
            loadingView.setText("No se pudo cargar");
            return;
        }

        String url = urls.get(index);
        ByteArrayRequest request = new ByteArrayRequest(
                url,
                data -> {
                    Bitmap bitmap = decodeBitmap(data, maxWidth, maxHeight);
                    if (bitmap != null) {
                        imageView.setImageBitmap(bitmap);
                        loadingView.setVisibility(View.GONE);
                        resolved[0] = url;
                    } else {
                        loadImageCandidates(urls, index + 1, imageView, loadingView, resolved, maxWidth, maxHeight);
                    }
                },
                error -> loadImageCandidates(urls, index + 1, imageView, loadingView, resolved, maxWidth, maxHeight));
        request.setShouldCache(true);
        imageQueue.add(request);
    }

    private String normalizeBase(String base) {
        if (base == null || base.trim().isEmpty())
            return "";
        String trimmed = base.trim();
        return trimmed.endsWith("/") ? trimmed : trimmed + "/";
    }

    private String normalizePath(String path) {
        if (path == null)
            return "";
        String trimmed = path.trim();
        return trimmed.startsWith("/") ? trimmed.substring(1) : trimmed;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private Bitmap decodeBitmap(byte[] data, int maxWidth, int maxHeight) {
        try {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inJustDecodeBounds = true;
            BitmapFactory.decodeByteArray(data, 0, data.length, options);

            options.inSampleSize = calculateInSampleSize(options, maxWidth, maxHeight);
            options.inJustDecodeBounds = false;
            options.inPreferredConfig = Bitmap.Config.RGB_565;

            Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length, options);
            if (bitmap == null)
                return null;

            int rotation = readExifRotation(data);
            if (rotation != 0) {
                Matrix matrix = new Matrix();
                matrix.postRotate(rotation);
                Bitmap rotated = Bitmap.createBitmap(bitmap, 0, 0,
                        bitmap.getWidth(), bitmap.getHeight(), matrix, true);
                if (rotated != bitmap) {
                    bitmap.recycle();
                }
                bitmap = rotated;
            }
            return bitmap;
        } catch (Exception e) {
            return null;
        }
    }

    private int readExifRotation(byte[] data) {
        try (ByteArrayInputStream input = new ByteArrayInputStream(data)) {
            ExifInterface exif = new ExifInterface(input);
            int orientation = exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL);
            if (orientation == ExifInterface.ORIENTATION_ROTATE_90)
                return 90;
            if (orientation == ExifInterface.ORIENTATION_ROTATE_180)
                return 180;
            if (orientation == ExifInterface.ORIENTATION_ROTATE_270)
                return 270;
            return 0;
        } catch (IOException e) {
            return 0;
        }
    }

    private int calculateInSampleSize(BitmapFactory.Options options, int reqWidth, int reqHeight) {
        int height = options.outHeight;
        int width = options.outWidth;
        int inSampleSize = 1;

        if (height > reqHeight || width > reqWidth) {
            int halfHeight = height / 2;
            int halfWidth = width / 2;
            while ((halfHeight / inSampleSize) >= reqHeight
                    && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2;
            }
        }
        return Math.max(1, inSampleSize);
    }

    private byte[] readBytes(InputStream inputStream) throws Exception {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] data = new byte[8192];
        int nRead;
        while ((nRead = inputStream.read(data, 0, data.length)) != -1) {
            buffer.write(data, 0, nRead);
        }
        buffer.flush();
        return buffer.toByteArray();
    }

    private static class MultipartRequest extends Request<String> {
        private final Response.Listener<String> listener;
        private final Response.ErrorListener errorListener;
        private final Map<String, String> params;
        private final String fileField;
        private final String fileName;
        private final String mimeType;
        private final byte[] fileData;
        private final String boundary;

        MultipartRequest(
                String url,
                Response.Listener<String> listener,
                Response.ErrorListener errorListener,
                Map<String, String> params,
                String fileField,
                String fileName,
                String mimeType,
                byte[] fileData) {
            super(Method.POST, url, errorListener);
            this.listener = listener;
            this.errorListener = errorListener;
            this.params = params;
            this.fileField = fileField;
            this.fileName = fileName;
            this.mimeType = mimeType;
            this.fileData = fileData;
            this.boundary = "----ClimaMania" + UUID.randomUUID().toString().replace("-", "");
        }

        @Override
        public String getBodyContentType() {
            return "multipart/form-data; boundary=" + boundary;
        }

        @Override
        public byte[] getBody() {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            String lineEnd = "\r\n";
            String twoHyphens = "--";

            try {
                for (Map.Entry<String, String> entry : params.entrySet()) {
                    bos.write((twoHyphens + boundary + lineEnd).getBytes("UTF-8"));
                    bos.write(("Content-Disposition: form-data; name=\"" + entry.getKey() + "\"" + lineEnd)
                            .getBytes("UTF-8"));
                    bos.write(lineEnd.getBytes("UTF-8"));
                    bos.write(entry.getValue().getBytes("UTF-8"));
                    bos.write(lineEnd.getBytes("UTF-8"));
                }

                bos.write((twoHyphens + boundary + lineEnd).getBytes("UTF-8"));
                bos.write(("Content-Disposition: form-data; name=\"" + fileField + "\"; filename=\"" + fileName + "\""
                        + lineEnd)
                        .getBytes("UTF-8"));
                bos.write(("Content-Type: " + mimeType + lineEnd).getBytes("UTF-8"));
                bos.write(lineEnd.getBytes("UTF-8"));
                bos.write(fileData);
                bos.write(lineEnd.getBytes("UTF-8"));

                bos.write((twoHyphens + boundary + twoHyphens + lineEnd).getBytes("UTF-8"));
            } catch (Exception e) {
                return new byte[0];
            }

            return bos.toByteArray();
        }

        @Override
        protected Response<String> parseNetworkResponse(com.android.volley.NetworkResponse response) {
            try {
                String parsed = new String(response.data,
                        HttpHeaderParser.parseCharset(response.headers, "UTF-8"));
                return Response.success(parsed, HttpHeaderParser.parseCacheHeaders(response));
            } catch (Exception e) {
                return Response.error(new com.android.volley.ParseError(e));
            }
        }

        @Override
        protected void deliverResponse(String response) {
            listener.onResponse(response);
        }

        @Override
        public void deliverError(VolleyError error) {
            errorListener.onErrorResponse(error);
        }
    }

    private static class ByteArrayRequest extends Request<byte[]> {
        private final Response.Listener<byte[]> listener;
        private final Response.ErrorListener errorListener;

        ByteArrayRequest(
                String url,
                Response.Listener<byte[]> listener,
                Response.ErrorListener errorListener) {
            super(Method.GET, url, errorListener);
            this.listener = listener;
            this.errorListener = errorListener;
        }

        @Override
        protected Response<byte[]> parseNetworkResponse(com.android.volley.NetworkResponse response) {
            return Response.success(response.data, HttpHeaderParser.parseCacheHeaders(response));
        }

        @Override
        protected void deliverResponse(byte[] response) {
            listener.onResponse(response);
        }

        @Override
        public void deliverError(VolleyError error) {
            errorListener.onErrorResponse(error);
        }
    }
}
