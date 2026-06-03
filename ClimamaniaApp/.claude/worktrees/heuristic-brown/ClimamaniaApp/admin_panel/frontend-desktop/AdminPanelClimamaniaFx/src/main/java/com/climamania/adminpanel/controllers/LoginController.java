package com.climamania.adminpanel.controllers;

import com.climamania.adminpanel.App;
import com.climamania.adminpanel.models.LoginResponse;
import com.climamania.adminpanel.net.ApiClient;
import javafx.application.Platform;
import javafx.fxml.FXML;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.PasswordField;
import javafx.scene.control.TextField;

public class LoginController {

    @FXML
    private TextField txtUsuario;

    @FXML
    private PasswordField txtContrasenya;

    @FXML
    private Button btnLogin;

    @FXML
    private Label lblStatus;

    private App app;

    public void setApp(App app) {
        this.app = app;
    }

    @FXML
    private void onLogin() {
        String usuario = txtUsuario.getText() == null ? "" : txtUsuario.getText().trim();
        String contrasenya = txtContrasenya.getText() == null ? "" : txtContrasenya.getText();

        if (usuario.isEmpty() || contrasenya.isEmpty()) {
            setStatus("Completa usuario y contrasenya");
            return;
        }

        setStatus("Validando...");
        btnLogin.setDisable(true);

        ApiClient.login(usuario, contrasenya)
                .thenAccept(this::handleLoginResponse)
                .exceptionally(ex -> {
                    Platform.runLater(() -> setStatus("Error de red"));
                    return null;
                })
                .whenComplete((r, ex) -> Platform.runLater(() -> btnLogin.setDisable(false)));
    }

    private void handleLoginResponse(LoginResponse response) {
        Platform.runLater(() -> {
            if (response == null || !response.isSuccess()) {
                setStatus(response != null ? response.getMessage() : "Credenciales invalidas");
                return;
            }
            ApiClient.setToken(response.getToken());
            try {
                app.showMain();
            } catch (Exception e) {
                setStatus("No se pudo abrir el panel");
            }
        });
    }

    private void setStatus(String message) {
        lblStatus.setText(message == null ? "" : message);
    }
}
