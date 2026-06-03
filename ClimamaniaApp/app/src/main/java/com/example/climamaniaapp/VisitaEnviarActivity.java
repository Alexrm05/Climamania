package com.example.climamaniaapp;

import android.Manifest;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;

import com.android.volley.DefaultRetryPolicy;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.Response;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.HttpHeaderParser;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.material.button.MaterialButton;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

public class VisitaEnviarActivity extends BaseActivity {

    private static final String API_KEY = "TEST123";
    private static final long MAX_UPLOAD_BYTES = 80L * 1024L * 1024L;
    private static final String URL_ENVIAR_COMENTARIO =
            "https://app.clminstal.es/api/visita_enviar_comentarios.php";
    private static final String URL_ENVIAR_FOTO_VIDEO =
            "https://app.clminstal.es/api/visita_enviar_fotos.php";
    private static final String URL_CAMBIAR_PRIORIDAD =
            "https://app.clminstal.es/api/visita_cambiar_prioridad.php";

    private TextView txtSaludo;
    private TextView txtRef;
    private TextView txtCliente;
    private TextView txtDireccion;

    private String idVisita = "";
    private String rolActual = "";
    private String usuarioActual = "";
    private String equipoActual = "";
    private String autorActual = "Instalador";
    private String inicialesActual = "APP";
    private String clienteActual = "";
    private String direccionActual = "";
    private String poblacionActual = "";

    private RequestQueue requestQueue;

    private ActivityResultLauncher<Uri> cameraLauncher;
    private ActivityResultLauncher<Intent> cameraVideoLauncher;
    private ActivityResultLauncher<String> galleryPhotoLauncher;
    private ActivityResultLauncher<String> galleryVideoLauncher;
    private ActivityResultLauncher<String> cameraPermissionLauncher;
    private Uri tempPhotoUri;
    private File tempPhotoFile;
    private Uri tempVideoUri;
    private File tempVideoFile;
    private boolean pendingVideoCapturePermission = false;
    private final ActivityResultLauncher<Intent> cerrarGestionLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    result -> {
                        if (result.getResultCode() == RESULT_OK) {
                            setResult(RESULT_OK);
                            finish();
                        }
                    });

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_visita_enviar, contentFrame, true);

        setupBottomBar();
        requestQueue = Volley.newRequestQueue(this);

        txtSaludo = content.findViewById(R.id.txtVisitaEnviarSaludo);
        txtRef = content.findViewById(R.id.txtVisitaEnviarRef);
        txtCliente = content.findViewById(R.id.txtVisitaEnviarCliente);
        txtDireccion = content.findViewById(R.id.txtVisitaEnviarDireccion);

        MaterialButton btnComentarios = content.findViewById(R.id.btnVisitaEnviarComentarios);
        MaterialButton btnFotos = content.findViewById(R.id.btnVisitaEnviarFotos);
        MaterialButton btnPrioridad = content.findViewById(R.id.btnVisitaEnviarPrioridad);
        MaterialButton btnFinalizar = content.findViewById(R.id.btnVisitaEnviarFinalizar);
        MaterialButton btnVolver = content.findViewById(R.id.btnVisitaEnviarVolver);

        applyStaggeredEntrance(
                content.findViewById(R.id.txtVisitaEnviarSaludo),
                content.findViewById(R.id.txtVisitaEnviarTitulo),
                content.findViewById(R.id.cardVisitaEnviarResumen),
                content.findViewById(R.id.btnVisitaEnviarComentarios),
                content.findViewById(R.id.btnVisitaEnviarFotos),
                content.findViewById(R.id.btnVisitaEnviarPrioridad),
                content.findViewById(R.id.btnVisitaEnviarFinalizar),
                content.findViewById(R.id.btnVisitaEnviarVolver));

        bindUserContext();
        bindDataFromIntent();
        setupUploadLaunchers();

        if (btnComentarios != null) {
            btnComentarios.setOnClickListener(v -> showComentarioDialog());
        }
        if (btnFotos != null) {
            btnFotos.setOnClickListener(v -> mostrarOpcionesSubida());
        }
        if (btnPrioridad != null) {
            btnPrioridad.setOnClickListener(v -> showPrioridadDialog());
        }
        if (btnFinalizar != null) {
            btnFinalizar.setOnClickListener(v -> abrirPantallaCierre());
        }
        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
    }

    private void bindUserContext() {
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }

        rolActual = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        usuarioActual = usuario;
        equipoActual = readEquipoFromPrefs(prefs);
        autorActual = !nombre.isEmpty() ? nombre : (!usuarioActual.isEmpty() ? usuarioActual : "Instalador");
        inicialesActual = resolveInitials(
                UiText.sanitizeDbValue(prefs.getString("k_iniciales", "")),
                autorActual);

        if (txtSaludo != null) {
            txtSaludo.setText("Hola " + autorActual);
        }
    }

    private void bindDataFromIntent() {
        idVisita = UiText.sanitizeDbValue(getIntent().getStringExtra("id_visita"));
        String cliente = UiText.sanitizeDbValue(getIntent().getStringExtra("cliente"));
        String direccion = UiText.sanitizeDbValue(getIntent().getStringExtra("direccion"));
        String poblacion = UiText.sanitizeDbValue(getIntent().getStringExtra("poblacion"));

        if (idVisita.isEmpty()) {
            Toast.makeText(this, "ID de visita no disponible", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        clienteActual = cliente;
        direccionActual = direccion;
        poblacionActual = poblacion;

        if (txtRef != null) {
            txtRef.setText("Visita #" + idVisita);
        }
        if (txtCliente != null) {
            txtCliente.setText(cliente.isEmpty() ? "Cliente no disponible" : cliente);
        }
        if (txtDireccion != null) {
            txtDireccion.setText(buildDireccion(direccion, poblacion));
        }
    }

    private void showComentarioDialog() {
        final EditText input = new EditText(this);
        input.setHint("Escribe el comentario para el muro");
        input.setMinLines(3);
        input.setMaxLines(6);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        int padding = dp(14);
        input.setPadding(padding, padding, padding, padding);

        new AlertDialog.Builder(this)
                .setTitle("Enviar comentarios escritos")
                .setView(input)
                .setPositiveButton("Enviar", (dialog, which) -> {
                    String mensaje = input.getText() != null ? input.getText().toString().trim() : "";
                    if (mensaje.isEmpty()) {
                        Toast.makeText(this, "Debes escribir un comentario", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    enviarComentario(mensaje);
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void enviarComentario(String mensaje) {
        Map<String, String> params = buildCommonParams();
        params.put("mensaje", mensaje);
        sendPostRequest(
                URL_ENVIAR_COMENTARIO,
                params,
                "Comentario enviado al muro",
                null);
    }

    private void showPrioridadDialog() {
        final String[] opciones = {"Alta", "Media", "Baja"};
        new AlertDialog.Builder(this)
                .setTitle("Cambiar prioridad de la visita")
                .setItems(opciones, (dialog, which) -> {
                    if (which >= 0 && which < opciones.length) {
                        cambiarPrioridad(opciones[which]);
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void cambiarPrioridad(String prioridad) {
        Map<String, String> params = buildCommonParams();
        params.put("prioridad", prioridad);
        sendPostRequest(
                URL_CAMBIAR_PRIORIDAD,
                params,
                "Prioridad actualizada",
                null);
    }

    private void abrirPantallaCierre() {
        Intent intent = new Intent(this, CerrarGestionActivity.class);
        intent.putExtra("tipo_caso", "visita");
        intent.putExtra("id_caso", idVisita);
        intent.putExtra("cliente", clienteActual);
        intent.putExtra("direccion", direccionActual);
        intent.putExtra("poblacion", poblacionActual);
        intent.putExtra("rol", rolActual);
        intent.putExtra("usuario", usuarioActual);
        intent.putExtra("equipo", equipoActual);
        intent.putExtra("autor", autorActual);
        cerrarGestionLauncher.launch(intent);
    }

    private void setupUploadLaunchers() {
        cameraPermissionLauncher = registerForActivityResult(
                new ActivityResultContracts.RequestPermission(),
                granted -> {
                    if (granted) {
                        boolean launchVideo = pendingVideoCapturePermission;
                        pendingVideoCapturePermission = false;
                        if (launchVideo) {
                            abrirCamaraVideo();
                        } else {
                            abrirCamara();
                        }
                    } else {
                        pendingVideoCapturePermission = false;
                        Toast.makeText(this, "Permiso de cámara denegado", Toast.LENGTH_SHORT).show();
                    }
                });

        cameraLauncher = registerForActivityResult(
                new ActivityResultContracts.TakePicture(),
                success -> {
                    if (success && tempPhotoFile != null) {
                        uploadFile(tempPhotoFile, "image/jpeg");
                    }
                });

        cameraVideoLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (result.getResultCode() == RESULT_OK) {
                        if (tempVideoFile != null && tempVideoFile.exists() && tempVideoFile.length() > 0) {
                            uploadFile(tempVideoFile, "video/mp4");
                            return;
                        }
                        Intent data = result.getData();
                        Uri uri = data != null ? data.getData() : null;
                        if (uri != null) {
                            uploadFromUri(uri);
                            return;
                        }
                    }
                    Toast.makeText(this, "No se pudo capturar el video", Toast.LENGTH_SHORT).show();
                });

        galleryPhotoLauncher = registerForActivityResult(
                new ActivityResultContracts.GetContent(),
                uri -> {
                    if (uri != null) {
                        uploadFromUri(uri);
                    }
                });

        galleryVideoLauncher = registerForActivityResult(
                new ActivityResultContracts.GetContent(),
                uri -> {
                    if (uri != null) {
                        uploadFromUri(uri);
                    }
                });
    }

    private void mostrarOpcionesSubida() {
        String[] items = {"Cámara (foto)", "Cámara (video)", "Galería (foto)", "Galería (video)"};
        new AlertDialog.Builder(this)
                .setTitle("Enviar fotos o videos")
                .setItems(items, (dialog, which) -> {
                    if (which == 0) {
                        abrirCamara();
                    } else if (which == 1) {
                        abrirCamaraVideo();
                    } else if (which == 2) {
                        abrirGaleriaFoto();
                    } else {
                        abrirGaleriaVideo();
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void abrirCamara() {
        pendingVideoCapturePermission = false;
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            if (cameraPermissionLauncher != null) {
                cameraPermissionLauncher.launch(Manifest.permission.CAMERA);
            }
            return;
        }

        try {
            File cacheDir = new File(getCacheDir(), "visitas");
            if (!cacheDir.exists()) {
                cacheDir.mkdirs();
            }
            tempPhotoFile = File.createTempFile("visita_", ".jpg", cacheDir);
            tempPhotoUri = FileProvider.getUriForFile(
                    this,
                    getPackageName() + ".fileprovider",
                    tempPhotoFile);
            cameraLauncher.launch(tempPhotoUri);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo abrir la cámara", Toast.LENGTH_SHORT).show();
        }
    }

    private void abrirCamaraVideo() {
        pendingVideoCapturePermission = true;
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            if (cameraPermissionLauncher != null) {
                cameraPermissionLauncher.launch(Manifest.permission.CAMERA);
            }
            return;
        }
        pendingVideoCapturePermission = false;

        try {
            File cacheDir = new File(getCacheDir(), "visitas");
            if (!cacheDir.exists()) {
                cacheDir.mkdirs();
            }
            tempVideoFile = File.createTempFile("visita_video_", ".mp4", cacheDir);
            tempVideoUri = FileProvider.getUriForFile(
                    this,
                    getPackageName() + ".fileprovider",
                    tempVideoFile);

            Intent intent = new Intent(android.provider.MediaStore.ACTION_VIDEO_CAPTURE);
            intent.putExtra(android.provider.MediaStore.EXTRA_OUTPUT, tempVideoUri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            if (cameraVideoLauncher != null) {
                cameraVideoLauncher.launch(intent);
            }
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo abrir la cámara de video", Toast.LENGTH_SHORT).show();
        }
    }

    private void abrirGaleriaFoto() {
        if (galleryPhotoLauncher != null) {
            galleryPhotoLauncher.launch("image/*");
        }
    }

    private void abrirGaleriaVideo() {
        if (galleryVideoLauncher != null) {
            galleryVideoLauncher.launch("video/*");
        }
    }

    private void uploadFile(File file, String mime) {
        if (file == null || !file.exists()) {
            Toast.makeText(this, "Archivo no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        if (file.length() > MAX_UPLOAD_BYTES) {
            Toast.makeText(this, "El archivo supera " + maxUploadLabel(), Toast.LENGTH_LONG).show();
            return;
        }
        try {
            byte[] data;
            try (FileInputStream in = new FileInputStream(file)) {
                data = readBytes(in);
            }
            uploadBytes(data, file.getName(), mime);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo leer el archivo", Toast.LENGTH_SHORT).show();
        }
    }

    private void uploadFromUri(Uri uri) {
        try {
            long declaredSize = resolveUriSize(uri);
            if (declaredSize > MAX_UPLOAD_BYTES) {
                Toast.makeText(this, "El archivo supera " + maxUploadLabel(), Toast.LENGTH_LONG).show();
                return;
            }
            byte[] data;
            try (InputStream in = getContentResolver().openInputStream(uri)) {
                if (in == null) {
                    Toast.makeText(this, "No se pudo leer el archivo", Toast.LENGTH_SHORT).show();
                    return;
                }
                data = readBytes(in);
            }
            String mime = resolveMimeType(uri);
            String name = ensureFileName(resolveDisplayName(uri), mime);
            uploadBytes(data, name, mime);
        } catch (Exception e) {
            Toast.makeText(this, "No se pudo leer el archivo", Toast.LENGTH_SHORT).show();
        }
    }

    private void uploadBytes(byte[] data, String filename, String mime) {
        if (idVisita.isEmpty()) {
            Toast.makeText(this, "ID de visita no disponible", Toast.LENGTH_SHORT).show();
            return;
        }
        if (data == null || data.length == 0) {
            Toast.makeText(this, "Archivo vacío", Toast.LENGTH_SHORT).show();
            return;
        }

        Toast.makeText(this, "Subiendo archivo...", Toast.LENGTH_SHORT).show();

        boolean imageMime = isImageMime(mime);
        byte[] payload = imageMime ? compressImageIfNeeded(data) : data;
        String finalName = imageMime ? ensureJpegName(filename) : ensureFileName(filename, mime);
        String finalMime = imageMime ? "image/jpeg" : mime;
        if (finalMime == null || finalMime.trim().isEmpty()) {
            finalMime = "application/octet-stream";
        }

        MultipartRequest request = new MultipartRequest(
                URL_ENVIAR_FOTO_VIDEO,
                response -> {
                    try {
                        JSONObject root = new JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            Toast.makeText(this,
                                    getJsonMessage(root, "No se pudo subir el archivo"),
                                    Toast.LENGTH_LONG).show();
                            return;
                        }
                        Toast.makeText(this,
                                getJsonMessage(root, "Archivo subido correctamente"),
                                Toast.LENGTH_SHORT).show();
                    } catch (Exception e) {
                        Toast.makeText(this, "Respuesta inválida al subir", Toast.LENGTH_SHORT).show();
                    }
                },
                error -> Toast.makeText(this,
                        buildVolleyErrorMessage(error, "Error de conexión al subir archivo"),
                        Toast.LENGTH_LONG).show(),
                buildUploadParams(),
                "archivo",
                finalName,
                finalMime,
                payload);
        request.setRetryPolicy(new DefaultRetryPolicy(30000, 1, 1.0f));
        request.setShouldCache(false);
        requestQueue.add(request);
    }

    private void sendPostRequest(
            String url,
            Map<String, String> params,
            String fallbackSuccessMessage,
            @Nullable JsonSuccessHandler onSuccess) {
        Map<String, String> payload = new HashMap<>(params);
        StringRequest request = new StringRequest(
                Request.Method.POST,
                url,
                response -> {
                    try {
                        JSONObject root = new JSONObject(response);
                        if (!root.optBoolean("success", false)) {
                            Toast.makeText(this,
                                    getJsonMessage(root, "No se pudo completar la acción"),
                                    Toast.LENGTH_LONG).show();
                            return;
                        }

                        Toast.makeText(this,
                                getJsonMessage(root, fallbackSuccessMessage),
                                Toast.LENGTH_SHORT).show();

                        if (onSuccess != null) {
                            onSuccess.onSuccess(root);
                        }
                    } catch (Exception e) {
                        Toast.makeText(this, "Respuesta inválida del servidor", Toast.LENGTH_SHORT).show();
                    }
                },
                error -> Toast.makeText(this,
                        buildVolleyErrorMessage(error, "Error de conexión con el servidor"),
                        Toast.LENGTH_LONG).show()) {
            @Override
            protected Map<String, String> getParams() {
                return payload;
            }
        };

        request.setRetryPolicy(new DefaultRetryPolicy(20000, 1, 1.0f));
        request.setShouldCache(false);
        requestQueue.add(request);
    }

    private Map<String, String> buildCommonParams() {
        Map<String, String> params = new HashMap<>();
        params.put("api_key", API_KEY);
        params.put("id_visita", idVisita);
        params.put("rol", rolActual);
        params.put("usuario", usuarioActual);
        params.put("equipo", equipoActual);
        params.put("autor", autorActual);
        return params;
    }

    private Map<String, String> buildUploadParams() {
        Map<String, String> params = buildCommonParams();
        params.put("k_iniciales", inicialesActual);
        return params;
    }

    private String getJsonMessage(JSONObject root, String fallback) {
        if (root == null) {
            return fallback;
        }
        String msg = UiText.sanitizeDbValue(root.optString("message", ""));
        return msg.isEmpty() ? fallback : msg;
    }

    private String buildVolleyErrorMessage(VolleyError error, String fallback) {
        if (error == null || error.networkResponse == null || error.networkResponse.data == null) {
            return fallback;
        }
        String body = new String(error.networkResponse.data, StandardCharsets.UTF_8).trim();
        return body.isEmpty() ? fallback : body;
    }

    private String buildDireccion(String direccion, String poblacion) {
        String dir = UiText.sanitizeDbValue(direccion);
        String pob = UiText.sanitizeDbValue(poblacion);
        if (dir.isEmpty() && pob.isEmpty()) {
            return "Direccion no disponible";
        }
        if (dir.isEmpty()) {
            return pob;
        }
        if (pob.isEmpty()) {
            return dir;
        }
        return dir + ", " + pob;
    }

    private String resolveMimeType(Uri uri) {
        if (uri == null) {
            return "application/octet-stream";
        }
        String mime = getContentResolver().getType(uri);
        if (mime != null && !mime.trim().isEmpty()) {
            return mime;
        }
        String name = resolveDisplayName(uri).toLowerCase(Locale.ROOT);
        if (name.endsWith(".mp4")) return "video/mp4";
        if (name.endsWith(".mov")) return "video/quicktime";
        if (name.endsWith(".m4v")) return "video/x-m4v";
        if (name.endsWith(".3gp")) return "video/3gpp";
        if (name.endsWith(".webm")) return "video/webm";
        if (name.endsWith(".avi")) return "video/x-msvideo";
        if (name.endsWith(".mkv")) return "video/x-matroska";
        if (name.endsWith(".mpeg")) return "video/mpeg";
        if (name.endsWith(".mpg")) return "video/mpeg";
        if (name.endsWith(".png")) return "image/png";
        if (name.endsWith(".gif")) return "image/gif";
        if (name.endsWith(".webp")) return "image/webp";
        if (name.endsWith(".heic")) return "image/heic";
        if (name.endsWith(".heif")) return "image/heif";
        return "image/jpeg";
    }

    private String resolveDisplayName(Uri uri) {
        if (uri == null) {
            return "";
        }
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
        return ext.isEmpty() ? "archivo" : "archivo." + ext;
    }

    private String extensionForMime(String mime) {
        String lower = mime == null ? "" : mime.toLowerCase(Locale.ROOT);
        if (lower.contains("video/mp4")) return "mp4";
        if (lower.contains("video/quicktime")) return "mov";
        if (lower.contains("video/x-m4v")) return "m4v";
        if (lower.contains("video/3gpp")) return "3gp";
        if (lower.contains("video/webm")) return "webm";
        if (lower.contains("video/x-msvideo")) return "avi";
        if (lower.contains("video/x-matroska")) return "mkv";
        if (lower.contains("video/mpeg")) return "mpeg";
        if (lower.contains("image/png")) return "png";
        if (lower.contains("image/gif")) return "gif";
        if (lower.contains("image/webp")) return "webp";
        if (lower.contains("image/heic")) return "heic";
        if (lower.contains("image/heif")) return "heif";
        if (lower.contains("image/jpeg") || lower.contains("image/jpg")) return "jpg";
        return "";
    }

    private byte[] compressImageIfNeeded(byte[] data) {
        if (data == null || data.length == 0) {
            return data;
        }
        try {
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            BitmapFactory.decodeByteArray(data, 0, data.length, bounds);
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                return data;
            }

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
            if (bitmap == null) {
                return data;
            }

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
        if (filename == null || filename.trim().isEmpty()) {
            return "foto.jpg";
        }
        String lower = filename.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
            return filename;
        }
        int dot = filename.lastIndexOf('.');
        if (dot > 0) {
            return filename.substring(0, dot) + ".jpg";
        }
        return filename + ".jpg";
    }

    private long resolveUriSize(Uri uri) {
        if (uri == null) {
            return -1L;
        }
        try (android.content.res.AssetFileDescriptor afd = getContentResolver().openAssetFileDescriptor(uri, "r")) {
            if (afd != null) {
                return afd.getLength();
            }
        } catch (Exception ignored) {
        }
        return -1L;
    }

    private String maxUploadLabel() {
        return (MAX_UPLOAD_BYTES / (1024L * 1024L)) + " MB";
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

    private String resolveInitials(String requested, String fallbackName) {
        String provided = UiText.sanitizeDbValue(requested).replaceAll("[^A-Za-z0-9]", "")
                .toUpperCase(Locale.ROOT);
        if (!provided.isEmpty()) {
            return provided.length() > 6 ? provided.substring(0, 6) : provided;
        }

        String base = UiText.sanitizeDbValue(fallbackName).toUpperCase(Locale.ROOT);
        if (base.isEmpty()) {
            return "APP";
        }

        String[] tokens = base.split("[^A-Za-z0-9]+");
        StringBuilder sb = new StringBuilder();
        for (String token : tokens) {
            String t = UiText.sanitizeDbValue(token);
            if (t.isEmpty()) {
                continue;
            }
            sb.append(t.charAt(0));
            if (sb.length() >= 3) {
                break;
            }
        }

        String initials = sb.length() > 0 ? sb.toString() : base.replaceAll("[^A-Za-z0-9]", "");
        if (initials.isEmpty()) {
            return "APP";
        }
        return initials.length() > 6 ? initials.substring(0, 6) : initials;
    }

    private void applyStaggeredEntrance(View... views) {
        int delay = 45;
        int current = 0;
        for (View v : views) {
            if (v == null) {
                continue;
            }
            v.setAlpha(0f);
            v.setTranslationY(dp(6));
            v.animate()
                    .alpha(1f)
                    .translationY(0f)
                    .setDuration(220L)
                    .setStartDelay(current)
                    .setInterpolator(new android.view.animation.DecelerateInterpolator())
                    .start();
            current += delay;
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private interface JsonSuccessHandler {
        void onSuccess(JSONObject root);
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
                        + lineEnd).getBytes("UTF-8"));
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
}
