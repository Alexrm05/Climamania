package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.ImageRequest;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import com.google.android.material.button.MaterialButton;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.URLEncoder;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class VisitaDetalleActivity extends BaseActivity {

    private static final String VISITA_DETALLE_URL = "https://app.clminstal.es/api/get_visita_detalle.php";
    private static final String PHOTO_BASE_URL = "https://clminstal.es/";
    private static final String PHOTO_ALT_BASE_URL = "https://app.clminstal.es/";
    private static final String PHOTO_API_URL = "https://app.clminstal.es/api/get_foto.php";
    private static final String API_KEY = "TEST123";

    private final SimpleDateFormat serverDateFormat = new SimpleDateFormat(
            "yyyy-MM-dd HH:mm:ss", Locale.getDefault());
    private final SimpleDateFormat displayDateFormat = new SimpleDateFormat(
            "dd/MM/yyyy HH:mm", Locale.forLanguageTag("es-ES"));

    private TextView txtSaludo;
    private TextView txtRef;
    private TextView txtLoading;
    private TextView txtCliente;
    private TextView txtDireccion;
    private TextView txtTelefono;
    private TextView txtPrioridad;
    private TextView txtEquipo;
    private TextView txtSolicitada;
    private TextView txtSolicita;
    private TextView txtMuroEmpty;
    private TextView txtFicherosEmpty;
    private LinearLayout llMuro;
    private LinearLayout llFicheros;

    private String idVisita;
    private JSONObject visitaActual;
    private boolean reloadAfterActions = false;
    private RequestQueue requestQueue;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_base);

        FrameLayout contentFrame = findViewById(R.id.contentFrame);
        View content = getLayoutInflater().inflate(R.layout.content_visita_detalle, contentFrame, true);

        setupBottomBar();
        requestQueue = Volley.newRequestQueue(this);

        txtSaludo = content.findViewById(R.id.txtDetalleVisitaSaludo);
        txtRef = content.findViewById(R.id.txtDetalleVisitaRef);
        txtLoading = content.findViewById(R.id.txtDetalleVisitaLoading);
        txtCliente = content.findViewById(R.id.txtDetalleVisitaCliente);
        txtDireccion = content.findViewById(R.id.txtDetalleVisitaDireccion);
        txtTelefono = content.findViewById(R.id.txtDetalleVisitaTelefono);
        txtPrioridad = content.findViewById(R.id.txtDetalleVisitaPrioridad);
        txtEquipo = content.findViewById(R.id.txtDetalleVisitaEquipo);
        txtSolicitada = content.findViewById(R.id.txtDetalleVisitaSolicitada);
        txtSolicita = content.findViewById(R.id.txtDetalleVisitaSolicita);
        txtMuroEmpty = content.findViewById(R.id.txtDetalleVisitaMuroEmpty);
        txtFicherosEmpty = content.findViewById(R.id.txtDetalleVisitaFicherosEmpty);
        llMuro = content.findViewById(R.id.llDetalleVisitaMuroList);
        llFicheros = content.findViewById(R.id.llDetalleVisitaFicherosList);

        MaterialButton btnVolver = content.findViewById(R.id.btnDetalleVisitaVolver);
        MaterialButton btnEnviarComercial = content.findViewById(R.id.btnDetalleVisitaEnviar);

        if (btnVolver != null) {
            btnVolver.setOnClickListener(v -> finish());
        }
        if (btnEnviarComercial != null) {
            btnEnviarComercial.setOnClickListener(v -> abrirPantallaEnviar());
        }

        applyStaggeredEntrance(
                content.findViewById(R.id.txtDetalleVisitaSaludo),
                content.findViewById(R.id.txtDetalleVisitaTitulo),
                content.findViewById(R.id.cardDetalleVisita),
                content.findViewById(R.id.btnDetalleVisitaEnviar));

        aplicarSaludoUsuario();

        idVisita = UiText.sanitizeDbValue(getIntent().getStringExtra("id_visita"));
        if (idVisita.isEmpty()) {
            Toast.makeText(this, "ID de visita no disponible", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        if (txtRef != null) {
            txtRef.setText("Visita #" + idVisita);
        }

        cargarDetalleVisita();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (reloadAfterActions && idVisita != null && !idVisita.isEmpty()) {
            reloadAfterActions = false;
            cargarDetalleVisita();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (requestQueue != null) {
            requestQueue.cancelAll("visita_detalle");
            requestQueue.cancelAll("visita_detalle_img");
        }
    }

    private void aplicarSaludoUsuario() {
        if (txtSaludo == null) {
            return;
        }
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        String displayName = !nombre.isEmpty() ? nombre : (!usuario.isEmpty() ? usuario : "instalador");
        txtSaludo.setText("Hola " + displayName);
    }

    private void cargarDetalleVisita() {
        if (txtLoading != null) {
            txtLoading.setVisibility(View.VISIBLE);
            txtLoading.setText("Cargando detalle de la visita...");
        }
        if (txtMuroEmpty != null) {
            txtMuroEmpty.setVisibility(View.GONE);
        }
        if (txtFicherosEmpty != null) {
            txtFicherosEmpty.setVisibility(View.GONE);
        }
        if (llMuro != null) {
            llMuro.removeAllViews();
        }
        if (llFicheros != null) {
            llFicheros.removeAllViews();
        }

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        String rol = UiText.sanitizeDbValue(prefs.getString("rol", ""));
        String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
        if (usuario.isEmpty()) {
            usuario = UiText.sanitizeDbValue(prefs.getString("remembered_username", ""));
        }
        String equipo = readEquipoFromPrefs(prefs);

        try {
            String url = VISITA_DETALLE_URL
                    + "?api_key=" + URLEncoder.encode(API_KEY, "UTF-8")
                    + "&id_visita=" + URLEncoder.encode(idVisita, "UTF-8")
                    + "&rol=" + URLEncoder.encode(rol, "UTF-8")
                    + "&equipo=" + URLEncoder.encode(equipo, "UTF-8")
                    + "&usuario=" + URLEncoder.encode(usuario, "UTF-8")
                    + "&_ts=" + System.currentTimeMillis();

            if (requestQueue == null) {
                requestQueue = Volley.newRequestQueue(this);
            }
            StringRequest request = new StringRequest(
                    Request.Method.GET,
                    url,
                    this::handleDetalleResponse,
                    error -> showError("No se pudo cargar el detalle de la visita"));
            request.setShouldCache(false);
            request.setTag("visita_detalle");
            requestQueue.add(request);
        } catch (Exception e) {
            showError("No se pudo cargar el detalle de la visita");
        }
    }

    private void handleDetalleResponse(String response) {
        try {
            JSONObject root = new JSONObject(response);
            if (!root.optBoolean("success", false)) {
                String message = UiText.sanitizeDbValue(root.optString("message", ""));
                showError(message.isEmpty() ? "No se pudo cargar el detalle de la visita" : message);
                return;
            }

            JSONObject visita = root.optJSONObject("visita");
            if (visita == null) {
                showError("Detalle de visita no disponible");
                return;
            }

            visitaActual = visita;
            bindVisita(visita);
            bindMuro(root.optJSONArray("muro"));
            bindFicheros(root.optJSONArray("ficheros"));

            if (txtLoading != null) {
                txtLoading.setVisibility(View.GONE);
            }
        } catch (Exception e) {
            showError("Respuesta inválida al cargar detalle de visita");
        }
    }

    private void bindVisita(JSONObject visita) {
        String cliente = UiText.sanitizeDbValue(visita.optString("cliente", ""));
        String direccion = UiText.sanitizeDbValue(visita.optString("direccion", ""));
        String poblacion = UiText.sanitizeDbValue(visita.optString("poblacion", ""));
        String telefono = UiText.sanitizeDbValue(visita.optString("telefono", ""));
        String equipoId = UiText.sanitizeDbValue(String.valueOf(visita.opt("equipo_id")));
        String fechaSolicitud = UiText.sanitizeDbValue(visita.optString("fecha_solicitud", ""));
        String solicitante = UiText.sanitizeDbValue(visita.optString("usuario_solicita", ""));
        String prioridadRaw = UiText.sanitizeDbValue(
                visita.optString("prioridad_label", visita.optString("prioridad", "")));

        PrioridadInfo prioridadInfo = parsePrioridad(prioridadRaw);

        if (txtCliente != null) {
            txtCliente.setText(cliente.isEmpty() ? "Cliente no disponible" : cliente);
        }
        if (txtDireccion != null) {
            txtDireccion.setText("Direccion: " + buildDireccion(direccion, poblacion));
        }
        if (txtTelefono != null) {
            txtTelefono.setText("Telefono: " + (telefono.isEmpty() ? "No disponible" : telefono));
        }
        if (txtPrioridad != null) {
            txtPrioridad.setText("Prioridad: " + prioridadInfo.label);
            txtPrioridad.setBackgroundResource(prioridadInfo.backgroundRes);
            txtPrioridad.setTextColor(prioridadInfo.textColor);
        }
        if (txtEquipo != null) {
            txtEquipo.setText("Equipo: " + (equipoId.isEmpty() || equipoId.equals("null") ? "N/D" : equipoId));
        }
        if (txtSolicitada != null) {
            txtSolicitada.setText("Solicitada: " + formatFecha(fechaSolicitud));
        }
        if (txtSolicita != null) {
            txtSolicita.setText("Solicita: " + (solicitante.isEmpty() ? "No disponible" : solicitante));
        }
    }

    private void bindMuro(@Nullable JSONArray muro) {
        if (llMuro == null || txtMuroEmpty == null) {
            return;
        }
        llMuro.removeAllViews();
        if (muro == null || muro.length() == 0) {
            txtMuroEmpty.setVisibility(View.VISIBLE);
            return;
        }
        txtMuroEmpty.setVisibility(View.GONE);

        for (int i = 0; i < muro.length(); i++) {
            JSONObject item = muro.optJSONObject(i);
            if (item == null) {
                continue;
            }
            View row = getLayoutInflater().inflate(R.layout.item_visita_muro, llMuro, false);
            TextView txtMensaje = row.findViewById(R.id.txtItemMuroMensaje);
            TextView txtMeta = row.findViewById(R.id.txtItemMuroMeta);

            String mensaje = UiText.sanitizeDbValue(item.optString("mensaje", ""));
            String autor = UiText.sanitizeDbValue(item.optString("autor", ""));
            String rol = UiText.sanitizeDbValue(item.optString("rol", ""));
            String fecha = UiText.sanitizeDbValue(item.optString("date_add", ""));

            txtMensaje.setText(mensaje.isEmpty() ? "Sin mensaje" : mensaje);
            txtMeta.setText(buildMuroMeta(autor, rol, fecha));

            llMuro.addView(row);
            animateRowEntrance(row, llMuro.getChildCount() - 1);
        }

        if (llMuro.getChildCount() == 0) {
            txtMuroEmpty.setVisibility(View.VISIBLE);
        }
    }

    private void bindFicheros(@Nullable JSONArray ficheros) {
        if (llFicheros == null || txtFicherosEmpty == null) {
            return;
        }
        llFicheros.removeAllViews();
        if (ficheros == null || ficheros.length() == 0) {
            txtFicherosEmpty.setVisibility(View.VISIBLE);
            return;
        }
        txtFicherosEmpty.setVisibility(View.GONE);

        for (int i = 0; i < ficheros.length(); i++) {
            JSONObject item = ficheros.optJSONObject(i);
            if (item == null) {
                continue;
            }
            View row = getLayoutInflater().inflate(R.layout.item_visita_fichero, llFicheros, false);
            TextView txtNombre = row.findViewById(R.id.txtItemFicheroNombre);
            TextView txtMeta = row.findViewById(R.id.txtItemFicheroMeta);
            ImageView imgPreview = row.findViewById(R.id.imgItemFicheroPreview);
            TextView txtPreviewHint = row.findViewById(R.id.txtItemFicheroPreviewHint);

            String ruta = UiText.sanitizeDbValue(item.optString("ruta", ""));
            String tipoFichero = UiText.sanitizeDbValue(item.optString("tipo_fichero", ""));
            String usuario = UiText.sanitizeDbValue(item.optString("usuario", ""));
            String fecha = UiText.sanitizeDbValue(item.optString("date_add", ""));

            txtNombre.setText(extractFileName(ruta));
            txtMeta.setText(buildFicheroMeta(tipoFichero, usuario, fecha));

            List<String> mediaUrls = buildPhotoCandidates(ruta);
            String[] resolvedUrl = {resolvePrimaryUrl(mediaUrls)};
            boolean isImage = isImageFile(ruta, tipoFichero);
            boolean isVideo = isVideoFile(ruta, tipoFichero);

            if (imgPreview != null) {
                imgPreview.setVisibility(isImage ? View.VISIBLE : View.GONE);
            }
            if (txtPreviewHint != null) {
                txtPreviewHint.setVisibility(isImage ? View.VISIBLE : View.GONE);
            }
            if (isImage && imgPreview != null) {
                loadImagePreview(mediaUrls, 0, imgPreview, resolvedUrl);
            }

            row.setOnClickListener(v -> openMedia(mediaUrls, resolvedUrl[0], isVideo));

            llFicheros.addView(row);
            animateRowEntrance(row, llFicheros.getChildCount() - 1);
        }

        if (llFicheros.getChildCount() == 0) {
            txtFicherosEmpty.setVisibility(View.VISIBLE);
        }
    }

    private String buildMuroMeta(String autor, String rol, String fechaRaw) {
        List<String> parts = new ArrayList<>();
        if (!autor.isEmpty()) {
            parts.add(autor);
        }
        if (!rol.isEmpty()) {
            parts.add(rol.toUpperCase(Locale.ROOT));
        }
        String fecha = formatFecha(fechaRaw);
        if (!fecha.equals("No disponible")) {
            parts.add(fecha);
        }
        return parts.isEmpty() ? "Sin datos" : joinParts(parts);
    }

    private String buildFicheroMeta(String tipoFichero, String usuario, String fechaRaw) {
        List<String> parts = new ArrayList<>();
        if (!tipoFichero.isEmpty()) {
            parts.add(tipoFichero);
        }
        if (!usuario.isEmpty()) {
            parts.add(usuario);
        }
        String fecha = formatFecha(fechaRaw);
        if (!fecha.equals("No disponible")) {
            parts.add(fecha);
        }
        return parts.isEmpty() ? "Sin datos" : joinParts(parts);
    }

    private String joinParts(List<String> parts) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < parts.size(); i++) {
            if (i > 0) {
                sb.append(" · ");
            }
            sb.append(parts.get(i));
        }
        return sb.toString();
    }

    private String buildDireccion(String direccion, String poblacion) {
        String dir = UiText.sanitizeDbValue(direccion);
        String pob = UiText.sanitizeDbValue(poblacion);
        if (dir.isEmpty() && pob.isEmpty()) {
            return "No disponible";
        }
        if (dir.isEmpty()) {
            return pob;
        }
        if (pob.isEmpty()) {
            return dir;
        }
        return dir + ", " + pob;
    }

    private String formatFecha(String rawDate) {
        String raw = UiText.sanitizeDbValue(rawDate);
        if (raw.isEmpty()) {
            return "No disponible";
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

    private String extractFileName(String path) {
        String clean = UiText.sanitizeDbValue(path);
        if (clean.isEmpty()) {
            return "Fichero sin nombre";
        }
        int q = clean.indexOf('?');
        if (q >= 0) {
            clean = clean.substring(0, q);
        }
        int idx = clean.lastIndexOf('/');
        return idx >= 0 ? clean.substring(idx + 1) : clean;
    }

    private List<String> buildPhotoCandidates(String path) {
        List<String> urls = new ArrayList<>();
        String trimmed = UiText.sanitizeDbValue(path);
        if (trimmed.isEmpty()) {
            return urls;
        }

        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            urls.add(trimmed);
        } else {
            try {
                String encodedPath = URLEncoder.encode(trimmed, "UTF-8");
                String encodedKey = URLEncoder.encode(API_KEY, "UTF-8");
                urls.add(PHOTO_API_URL + "?api_key=" + encodedKey + "&doc=" + encodedPath);
            } catch (Exception ignored) {
                // Si falla la codificacion usamos solo rutas directas.
            }
            urls.add(normalizeBase(PHOTO_BASE_URL) + normalizePath(trimmed));
            urls.add(normalizeBase(PHOTO_ALT_BASE_URL) + normalizePath(trimmed));
        }

        List<String> expanded = new ArrayList<>();
        for (String url : urls) {
            if (url == null || url.trim().isEmpty()) {
                continue;
            }
            String clean = url.trim();
            expanded.add(clean);
            if (clean.startsWith("https://")) {
                expanded.add("http://" + clean.substring("https://".length()));
            }
        }
        return expanded;
    }

    private String resolvePrimaryUrl(List<String> urls) {
        if (urls == null || urls.isEmpty()) {
            return "";
        }
        String url = UiText.sanitizeDbValue(urls.get(0));
        return url.isEmpty() ? "" : url;
    }

    private void loadImagePreview(List<String> urls, int index, ImageView imageView, String[] resolvedUrl) {
        if (requestQueue == null || imageView == null || urls == null || index >= urls.size()) {
            return;
        }
        String url = UiText.sanitizeDbValue(urls.get(index));
        if (url.isEmpty()) {
            loadImagePreview(urls, index + 1, imageView, resolvedUrl);
            return;
        }

        ImageRequest imageRequest = new ImageRequest(
                url,
                bitmap -> {
                    imageView.setImageBitmap(bitmap);
                    if (resolvedUrl != null && resolvedUrl.length > 0) {
                        resolvedUrl[0] = url;
                    }
                },
                dp(1200),
                dp(1200),
                ImageView.ScaleType.CENTER_CROP,
                Bitmap.Config.RGB_565,
                error -> loadImagePreview(urls, index + 1, imageView, resolvedUrl));
        imageRequest.setTag("visita_detalle_img");
        imageRequest.setShouldCache(true);
        requestQueue.add(imageRequest);
    }

    private void openMedia(List<String> urls, String fallbackUrl, boolean isVideo) {
        String url = UiText.sanitizeDbValue(fallbackUrl);
        if (url.isEmpty()) {
            url = resolvePrimaryUrl(urls);
        }
        if (url.isEmpty()) {
            Toast.makeText(this, "Fichero no disponible", Toast.LENGTH_SHORT).show();
            return;
        }

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

        Intent intent = new Intent(this, WebViewActivity.class);
        intent.putExtra("target_url", url);
        startActivity(intent);
    }

    private boolean isImageFile(String path, String tipoFichero) {
        String value = UiText.sanitizeDbValue(path).toLowerCase(Locale.ROOT);
        int q = value.indexOf('?');
        if (q >= 0) {
            value = value.substring(0, q);
        }
        if (value.endsWith(".jpg") || value.endsWith(".jpeg") || value.endsWith(".png")
                || value.endsWith(".gif") || value.endsWith(".webp") || value.endsWith(".bmp")) {
            return true;
        }
        String tipo = UiText.sanitizeDbValue(tipoFichero).toLowerCase(Locale.ROOT);
        return tipo.contains("image") || tipo.contains("foto") || tipo.contains("jpg")
                || tipo.contains("jpeg") || tipo.contains("png");
    }

    private boolean isVideoFile(String path, String tipoFichero) {
        String value = UiText.sanitizeDbValue(path).toLowerCase(Locale.ROOT);
        int q = value.indexOf('?');
        if (q >= 0) {
            value = value.substring(0, q);
        }
        if (value.endsWith(".mp4") || value.endsWith(".mov") || value.endsWith(".m4v")
                || value.endsWith(".3gp") || value.endsWith(".webm")
                || value.endsWith(".avi") || value.endsWith(".mkv")
                || value.endsWith(".mpeg") || value.endsWith(".mpg")) {
            return true;
        }
        String tipo = UiText.sanitizeDbValue(tipoFichero).toLowerCase(Locale.ROOT);
        return tipo.contains("video");
    }

    private String normalizeBase(String base) {
        String clean = UiText.sanitizeDbValue(base);
        if (clean.isEmpty()) {
            return "";
        }
        return clean.endsWith("/") ? clean : clean + "/";
    }

    private String normalizePath(String path) {
        String clean = UiText.sanitizeDbValue(path);
        if (clean.startsWith("/")) {
            return clean.substring(1);
        }
        return clean;
    }

    private void abrirPantallaEnviar() {
        Intent intent = new Intent(this, VisitaEnviarActivity.class);
        intent.putExtra("id_visita", idVisita);

        if (visitaActual != null) {
            intent.putExtra("cliente", UiText.sanitizeDbValue(visitaActual.optString("cliente", "")));
            intent.putExtra("direccion", UiText.sanitizeDbValue(visitaActual.optString("direccion", "")));
            intent.putExtra("poblacion", UiText.sanitizeDbValue(visitaActual.optString("poblacion", "")));
        }

        reloadAfterActions = true;
        startActivity(intent);
    }

    private void showError(String message) {
        String msg = UiText.sanitizeDbValue(message);
        if (msg.isEmpty()) {
            msg = "No se pudo cargar el detalle de la visita";
        }
        if (txtLoading != null) {
            txtLoading.setText(msg);
            txtLoading.setVisibility(View.VISIBLE);
        }
        if (txtMuroEmpty != null) {
            txtMuroEmpty.setVisibility(View.GONE);
        }
        if (txtFicherosEmpty != null) {
            txtFicherosEmpty.setVisibility(View.GONE);
        }
        if (llMuro != null) {
            llMuro.removeAllViews();
        }
        if (llFicheros != null) {
            llFicheros.removeAllViews();
        }
    }

    private PrioridadInfo parsePrioridad(String raw) {
        String value = UiText.sanitizeDbValue(raw);
        if (value.isEmpty()) {
            return new PrioridadInfo("Sin prioridad", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
        }

        String lower = value.toLowerCase(Locale.ROOT);
        if (lower.equals("alta") || lower.equals("high") || lower.equals("urgente")) {
            return new PrioridadInfo("Alta", R.drawable.bg_priority_high, Color.WHITE);
        }
        if (lower.equals("media") || lower.equals("medio") || lower.equals("normal")) {
            return new PrioridadInfo("Media", R.drawable.bg_priority_medium, Color.WHITE);
        }
        if (lower.equals("baja") || lower.equals("low")) {
            return new PrioridadInfo("Baja", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
        }

        if (value.matches("\\d+")) {
            int n = Integer.parseInt(value);
            if (n >= 3) {
                return new PrioridadInfo("Alta", R.drawable.bg_priority_high, Color.WHITE);
            }
            if (n == 2) {
                return new PrioridadInfo("Media", R.drawable.bg_priority_medium, Color.WHITE);
            }
            return new PrioridadInfo("Baja", R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
        }

        return new PrioridadInfo(value, R.drawable.bg_priority_low, Color.parseColor("#1F2937"));
    }

    private void animateRowEntrance(View row, int index) {
        if (row == null) {
            return;
        }
        row.setAlpha(0f);
        row.setTranslationY(dp(8));
        row.animate()
                .alpha(1f)
                .translationY(0f)
                .setStartDelay(Math.min(index, 10) * 40L)
                .setDuration(220L)
                .setInterpolator(new android.view.animation.DecelerateInterpolator())
                .start();
    }

    private void applyStaggeredEntrance(View... views) {
        int delay = 50;
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

    private static final class PrioridadInfo {
        final String label;
        final int backgroundRes;
        final int textColor;

        PrioridadInfo(String label, int backgroundRes, int textColor) {
            this.label = label;
            this.backgroundRes = backgroundRes;
            this.textColor = textColor;
        }
    }
}
