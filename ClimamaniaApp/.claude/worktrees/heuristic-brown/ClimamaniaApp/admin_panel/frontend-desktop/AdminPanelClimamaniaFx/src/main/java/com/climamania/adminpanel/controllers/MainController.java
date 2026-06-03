package com.climamania.adminpanel.controllers;

import com.climamania.adminpanel.App;
import javafx.fxml.FXML;
import javafx.scene.control.Label;

public class MainController {

    @FXML
    private Label lblWelcome;

    private App app;

    public void setApp(App app) {
        this.app = app;
    }

    @FXML
    private void initialize() {
        lblWelcome.setText("Panel de administracion");
    }
}
