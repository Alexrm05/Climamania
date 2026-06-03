package com.climamania.adminpanel.models;

public class LoginResponse {

    private final boolean success;
    private final String token;
    private final String usuario;
    private final String rol;
    private final String message;

    private LoginResponse(boolean success, String token, String usuario, String rol, String message) {
        this.success = success;
        this.token = token;
        this.usuario = usuario;
        this.rol = rol;
        this.message = message;
    }

    public static LoginResponse ok(String token, String usuario, String rol) {
        return new LoginResponse(true, token, usuario, rol, "");
    }

    public static LoginResponse error(String message) {
        return new LoginResponse(false, "", "", "", message == null ? "" : message);
    }

    public boolean isSuccess() {
        return success;
    }

    public String getToken() {
        return token;
    }

    public String getUsuario() {
        return usuario;
    }

    public String getRol() {
        return rol;
    }

    public String getMessage() {
        return message;
    }
}
