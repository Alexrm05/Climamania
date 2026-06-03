package com.example.climamaniaapp;

import androidx.room.Entity;
import androidx.room.PrimaryKey;
import androidx.room.Ignore;

import java.util.Calendar;

@Entity(tableName = "eventos")
public class Evento {
    @PrimaryKey(autoGenerate = true)
    public long id;

    // Guardamos la fecha como Calendar (con TypeConverter a long)
    public Calendar fecha;       // Fecha exacta del evento
    public int startHourIndex;   // Índice de la hora de inicio (0=08:00, 1=09:00, etc.)
    public int duration;         // Duración en horas
    public String pedido;        // Nº de pedido
    public String direccion;     // Dirección del cliente
    public String cliente;       // Nombre del cliente

    // Campos adicionales solo para la UI (no se persisten en Room)
    @Ignore
    public String equipoCodigo;   // Código de equipo tal como viene de la BD (FCB, FCB2, JZ...)

    // Color del evento, tal como viene de la BD (columna "color": #RRGGBB, etc.)
    @Ignore
    public String colorHex;

    @Ignore
    public String detalles;       // Detalles técnicos de la instalación

    @Ignore
    public String comentarios;    // Comentarios internos

    @Ignore
    public String emailEquipo;    // Email del equipo de instaladores

    @Ignore
    public String concertada;     // Indica si la visita está confirmada

    @Ignore
    public String telefono;

    @Ignore
    public String whatsapp;

    @Ignore
    public String estado;

    @Ignore
    public String titulo;

    @Ignore
    public Evento(Calendar fecha, int startHourIndex, int duration,
                  String pedido, String direccion, String cliente) {
        this.fecha = fecha;
        this.startHourIndex = startHourIndex;
        this.duration = duration;
        this.pedido = pedido;
        this.direccion = direccion;
        this.cliente = cliente;
    }

    // Constructor vacio requerido por Room
    public Evento() {
    }

    // --- Getters ---
    public Calendar getFecha() {
        return fecha;
    }

    public int getStartHourIndex() {
        return startHourIndex;
    }

    public int getDuration() {
        return duration;
    }

    public String getPedido() {
        return pedido;
    }

    public String getDireccion() {
        return direccion;
    }

    public String getCliente() {
        return cliente;
    }

    // Devuelve la franja horaria en formato "HH:00 - HH:00"
    public String getHoraPrevista(String[] hours) {
        String inicio = hours[startHourIndex];
        int finIndex = startHourIndex + duration;
        String fin = (finIndex < hours.length) ? hours[finIndex] : "Fin";
        return inicio + " - " + fin;
    }

    // Texto que se mostrará dentro de la tarjeta
    public String getTextoEvento(String[] hours) {
        String pedidoSafe = UiText.displayValue(pedido, "Sin pedido");
        String clienteSafe = UiText.displayValue(cliente, "Cliente no disponible");
        String direccionSafe = UiText.displayValue(direccion, "Dirección no disponible");
        return "⏰ " + getHoraPrevista(hours) + "\n"
                + "📦 " + pedidoSafe + "\n"
                + "👤 " + clienteSafe + "\n"
                + "📍 " + direccionSafe;
    }
}
