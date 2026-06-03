package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.material.button.MaterialButton;

import org.json.JSONException;
import org.json.JSONObject;

public class LoginActivity extends AppCompatActivity {

    private EditText editUser, editPass;
    private ImageView btnTogglePassword;
    private CheckBox checkRememberUser;
    private boolean isPasswordVisible = false;
    // Endpoint real en el servidor (dentro de /api)
    private static final String LOGIN_URL = "https://app.clminstal.es/api/login.php";
    private static final String API_KEY = "TEST123";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Auto-login si ya hay sesión activa en este dispositivo
        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        boolean loggedIn = prefs.getBoolean("logged_in", false);
        String savedUser = prefs.getString("usuario", "");
        if (loggedIn && savedUser != null && !savedUser.trim().isEmpty()) {
            Intent intent = new Intent(LoginActivity.this, MainActivity.class);
            startActivity(intent);
            finish();
            return;
        }

        setContentView(R.layout.activity_login);

        // Animación suave de entrada de la pantalla de login
        View root = findViewById(android.R.id.content);
        if (root != null) {
            root.setAlpha(0f);
            root.animate().alpha(1f).setDuration(220).start();
        }

        editUser = findViewById(R.id.editUser);
        editPass = findViewById(R.id.editPass);
        btnTogglePassword = findViewById(R.id.btnTogglePassword);
        checkRememberUser = findViewById(R.id.checkRememberUser);
        MaterialButton btnLogin = findViewById(R.id.btnLogin);
        MaterialButton btnClear = findViewById(R.id.btnClear);

        // Cargar usuario recordado (si existe)
        boolean remember = prefs.getBoolean("remember_user", false);
        if (remember) {
            String rememberedUser = prefs.getString("remembered_username", "");
            String rememberedPass = prefs.getString("remembered_password", "");
            editUser.setText(rememberedUser);
            editPass.setText(rememberedPass);
            checkRememberUser.setChecked(true);
        }

        // 👁️ Botón mostrar/ocultar contraseña
        btnTogglePassword.setOnClickListener(v -> {
            if (isPasswordVisible) {
                // Ocultar contraseña
                editPass.setInputType(
                        android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);
                btnTogglePassword.setImageResource(R.drawable.ic_visibility_off);
            } else {
                // Mostrar contraseña
                editPass.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                        | android.text.InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD);
                btnTogglePassword.setImageResource(R.drawable.ic_visibility);
            }
            editPass.setSelection(editPass.length()); // mantener cursor al final
            isPasswordVisible = !isPasswordVisible;
        });

        // 🔐 Botón de login
        btnLogin.setOnClickListener(v -> attemptLogin());

        // 🧹 Botón para limpiar rápidamente usuario y contraseña
        if (btnClear != null) {
            btnClear.setOnClickListener(v -> {
                editUser.setText("");
                editPass.setText("");
                checkRememberUser.setChecked(false);

                SharedPreferences.Editor editor = prefs.edit();
                editor.putBoolean("remember_user", false);
                editor.remove("remembered_username");
                editor.remove("remembered_password");
                editor.apply();
            });
        }
    }

    private void attemptLogin() {
        String usuario = editUser.getText().toString().trim();
        String password = editPass.getText().toString().trim();

        if (usuario.isEmpty() || password.isEmpty()) {
            Toast.makeText(this, "Por favor, completa todos los campos", Toast.LENGTH_SHORT).show();
            return;
        }

        // Enviar petición POST con Volley como form-urlencoded (StringRequest)
        StringRequest stringRequest = new StringRequest(
                Request.Method.POST,
                LOGIN_URL,
                response -> {
                    try {
                        // El servidor debería devolver JSON; lo parseamos desde el String
                        org.json.JSONObject json = new org.json.JSONObject(response);
                        boolean success = json.optBoolean("success", false);

                        if (success) {
                            persistLoginAndEnterMain(json, usuario, password);
                        } else {
                            String message = json.optString("message", "Usuario o contraseña incorrectos");
                            Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
                        }
                    } catch (org.json.JSONException e) {
                        // Intentar extraer JSON embebido dentro de una respuesta HTML/texto
                        String trimmed = response == null ? "" : response.trim();
                        int start = trimmed.indexOf('{');
                        int end = trimmed.lastIndexOf('}');
                        if (start != -1 && end != -1 && end > start) {
                            String possible = trimmed.substring(start, end + 1);
                            try {
                                JSONObject json2 = new JSONObject(possible);
                                boolean success2 = json2.optBoolean("success", false);
                                if (success2) {
                                    persistLoginAndEnterMain(json2, usuario, password);
                                } else {
                                    String message2 = json2.optString("message", "Usuario o contraseña incorrectos");
                                    Toast.makeText(this, message2, Toast.LENGTH_SHORT).show();
                                }
                                return;
                            } catch (org.json.JSONException ex) {
                                // No se pudo parsear el fragmento encontrado
                            }
                        }

                        // Fallback: loguear respuesta completa para depuración y mostrar mensaje
                        // amigable
                        android.util.Log.e("LoginActivity", "Non-JSON response from server: " + response);
                        Toast.makeText(this, "Error del servidor: respuesta inválida", Toast.LENGTH_LONG).show();
                    }
                },
                error -> {
                    String msg;
                    if (error.networkResponse != null) {
                        int statusCode = error.networkResponse.statusCode;
                        String body = "";
                        try {
                            body = new String(error.networkResponse.data, "UTF-8");
                        } catch (Exception ignored) {
                        }
                        android.util.Log.e("LoginActivity",
                                "Volley error. HTTP " + statusCode + " Body: " + body, error);
                        msg = "Error de conexión (HTTP " + statusCode + ")";
                    } else {
                        android.util.Log.e("LoginActivity", "Volley error sin respuesta", error);
                        msg = "Error de conexión: "
                                + (error.getMessage() != null ? error.getMessage() : error.toString());
                    }
                    Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                }) {
            @Override
            protected java.util.Map<String, String> getParams() {
                java.util.Map<String, String> params = new java.util.HashMap<>();
                params.put("usuario", usuario);
                // Enviamos ambos nombres de campo para máxima compatibilidad
                params.put("password", password); // para scripts antiguos
                params.put("contrasenya", password); // para el nuevo login.php
                params.put("api_key", API_KEY); // usado por el nuevo login.php
                return params;
            }
        };

        // Cola de peticiones
        RequestQueue queue = Volley.newRequestQueue(this);
        queue.add(stringRequest);
    }

    private void persistLoginAndEnterMain(JSONObject json, String usuarioInput, String passwordInput) {
        String nombre = UiText.sanitizeDbValue(json.optString("nombre", usuarioInput));

        SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("usuario", UiText.sanitizeDbValue(json.optString("usuario", usuarioInput)));
        editor.putString("nombre", UiText.sanitizeDbValue(json.optString("nombre", "")));
        editor.putString("apellidos", UiText.sanitizeDbValue(json.optString("apellidos", "")));
        editor.putString("email", UiText.sanitizeDbValue(json.optString("email", "")));
        editor.putString("rol", UiText.sanitizeDbValue(json.optString("rol", "")));
        String equipoRaw = UiText.sanitizeDbValue(json.optString("equipoInstaladores", ""));
        if (equipoRaw.isEmpty()) {
            equipoRaw = String.valueOf(json.optInt("equipoInstaladores", 0));
        }
        editor.putString("equipoInstaladores", equipoRaw.trim());
        editor.putBoolean("logged_in", true);
        if (checkRememberUser != null && checkRememberUser.isChecked()) {
            editor.putBoolean("remember_user", true);
            editor.putString("remembered_username", usuarioInput);
            editor.putString("remembered_password", passwordInput);
        } else {
            editor.putBoolean("remember_user", false);
            editor.remove("remembered_username");
            editor.remove("remembered_password");
        }
        editor.apply();

        if (!nombre.isEmpty()) {
            Toast.makeText(this, "Bienvenido " + nombre, Toast.LENGTH_SHORT).show();
        } else {
            Toast.makeText(this, "Bienvenido", Toast.LENGTH_SHORT).show();
        }
        Intent intent = new Intent(LoginActivity.this, MainActivity.class);
        startActivity(intent);
        finish();
    }
}
