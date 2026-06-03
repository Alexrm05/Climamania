package com.climamania.adminpanel;

import com.climamania.adminpanel.controllers.LoginController;
import com.climamania.adminpanel.controllers.MainController;
import javafx.application.Application;
import javafx.fxml.FXMLLoader;
import javafx.scene.Scene;
import javafx.stage.Stage;

public class App extends Application {

    private Stage primaryStage;

    @Override
    public void start(Stage stage) throws Exception {
        this.primaryStage = stage;
        showLogin();
        stage.setTitle("Admin Panel ClimaMania");
        stage.show();
    }

    public void showLogin() throws Exception {
        FXMLLoader loader = new FXMLLoader(getClass().getResource("/com/climamania/adminpanel/login-view.fxml"));
        Scene scene = new Scene(loader.load(), 900, 520);
        scene.getStylesheets().add(getClass().getResource("/com/climamania/adminpanel/app.css").toExternalForm());

        LoginController controller = loader.getController();
        controller.setApp(this);

        primaryStage.setScene(scene);
    }

    public void showMain() throws Exception {
        FXMLLoader loader = new FXMLLoader(getClass().getResource("/com/climamania/adminpanel/main-view.fxml"));
        Scene scene = new Scene(loader.load(), 1100, 700);
        scene.getStylesheets().add(getClass().getResource("/com/climamania/adminpanel/app.css").toExternalForm());

        MainController controller = loader.getController();
        controller.setApp(this);

        primaryStage.setScene(scene);
    }

    public static void main(String[] args) {
        launch();
    }
}
