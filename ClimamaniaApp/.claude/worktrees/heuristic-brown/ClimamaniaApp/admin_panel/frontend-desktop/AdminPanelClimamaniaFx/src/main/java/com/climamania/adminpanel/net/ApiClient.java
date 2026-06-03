package com.climamania.adminpanel.net;

import com.climamania.adminpanel.models.LoginResponse;
import org.json.JSONObject;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.CompletableFuture;

public class ApiClient {

    private static final HttpClient CLIENT = HttpClient.newHttpClient();
    private static String baseUrl = "https://app.clminstal.es";
    private static String token = "";

    public static void setBaseUrl(String url) {
        baseUrl = url == null ? "" : url.trim();
    }

    public static void setToken(String value) {
        token = value == null ? "" : value.trim();
    }

    public static CompletableFuture<LoginResponse> login(String usuario, String contrasenya) {
        JSONObject body = new JSONObject();
        body.put("usuario", usuario);
        body.put("contrasenya", contrasenya);

        String url = baseUrl + "/admin/login.php";
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body.toString(), StandardCharsets.UTF_8))
                .build();

        return CLIENT.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(response -> {
                    if (response.statusCode() >= 400) {
                        return LoginResponse.error("Error HTTP " + response.statusCode());
                    }
                    JSONObject json = new JSONObject(response.body());
                    boolean success = json.optBoolean("success", false);
                    if (!success) {
                        return LoginResponse.error(json.optString("message", "Credenciales invalidas"));
                    }
                    String token = json.optString("token", "");
                    String usuarioResp = json.optString("usuario", "");
                    String rol = json.optString("rol", "");
                    return LoginResponse.ok(token, usuarioResp, rol);
                });
    }

    public static HttpRequest.Builder withAuth(HttpRequest.Builder builder) {
        if (token != null && !token.isEmpty()) {
            builder.header("Authorization", "Bearer " + token);
        }
        return builder;
    }
}
