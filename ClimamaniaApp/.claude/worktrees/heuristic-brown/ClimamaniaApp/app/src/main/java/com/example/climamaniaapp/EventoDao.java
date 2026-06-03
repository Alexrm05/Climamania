package com.example.climamaniaapp;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;

import java.util.List;

@Dao
public interface EventoDao {

    @Query("SELECT * FROM eventos ORDER BY fecha ASC")
    List<Evento> getAll();

    @Insert
    void insert(Evento... eventos);
}
