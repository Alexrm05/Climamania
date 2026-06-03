package com.example.climamaniaapp;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Handler;
import android.os.Looper;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

final class EventLocationCaptureHelper {

    interface Callback {
        void onLocationReady(@NonNull CapturedLocation location);

        void onLocationError(@NonNull String message);
    }

    static final class CapturedLocation {
        final double latitude;
        final double longitude;

        CapturedLocation(double latitude, double longitude) {
            this.latitude = latitude;
            this.longitude = longitude;
        }

        String latitudeParam() {
            return String.format(Locale.US, "%.7f", latitude);
        }

        String longitudeParam() {
            return String.format(Locale.US, "%.7f", longitude);
        }
    }

    private static final long MAX_LAST_KNOWN_AGE_MS = 5L * 60L * 1000L;
    private static final long UPDATE_TIMEOUT_MS = 12000L;

    private final BaseActivity activity;
    private final LocationManager locationManager;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ActivityResultLauncher<String[]> permissionLauncher;

    private Callback pendingCallback;
    private LocationListener activeListener;
    private boolean requestInFlight = false;

    EventLocationCaptureHelper(@NonNull BaseActivity activity) {
        this.activity = activity;
        this.locationManager = (LocationManager) activity.getSystemService(Context.LOCATION_SERVICE);
        this.permissionLauncher = activity.registerForActivityResult(
                new ActivityResultContracts.RequestMultiplePermissions(),
                this::handlePermissionResult);
    }

    void capture(@NonNull Callback callback) {
        if (requestInFlight) {
            callback.onLocationError("Ya se está obteniendo la ubicación");
            return;
        }
        pendingCallback = callback;
        if (!hasAnyLocationPermission()) {
            permissionLauncher.launch(new String[] {
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
            });
            return;
        }
        startCapture();
    }

    void stop() {
        clearActiveRequest();
        pendingCallback = null;
        requestInFlight = false;
    }

    private void handlePermissionResult(Map<String, Boolean> result) {
        boolean granted = false;
        if (result != null) {
            Boolean fine = result.get(Manifest.permission.ACCESS_FINE_LOCATION);
            Boolean coarse = result.get(Manifest.permission.ACCESS_COARSE_LOCATION);
            granted = Boolean.TRUE.equals(fine) || Boolean.TRUE.equals(coarse);
        }
        if (!granted && !hasAnyLocationPermission()) {
            deliverError("Se necesita permiso de ubicación para continuar");
            return;
        }
        startCapture();
    }

    private void startCapture() {
        if (locationManager == null) {
            deliverError("No se pudo acceder al servicio de ubicación");
            return;
        }
        List<String> providers = getAllowedEnabledProviders();
        if (providers.isEmpty()) {
            deliverError("Activa la ubicación del dispositivo para continuar");
            return;
        }

        requestInFlight = true;
        Location bestLastKnown = findBestRecentLocation(providers);
        if (bestLastKnown != null) {
            deliverSuccess(bestLastKnown);
            return;
        }

        LocationListener listener = location -> {
            if (isUsableLocation(location)) {
                deliverSuccess(location);
            }
        };
        activeListener = listener;

        try {
            for (String provider : providers) {
                locationManager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper());
            }
        } catch (SecurityException e) {
            deliverError("No se pudo obtener la ubicación con los permisos actuales");
            return;
        } catch (Exception e) {
            deliverError("No se pudo iniciar la ubicación. Inténtalo de nuevo");
            return;
        }

        mainHandler.postDelayed(() -> {
            if (!requestInFlight) {
                return;
            }
            Location retryLocation = findBestRecentLocation(getAllowedEnabledProviders());
            if (retryLocation != null) {
                deliverSuccess(retryLocation);
                return;
            }
            deliverError("No se pudo obtener una ubicación válida. Inténtalo de nuevo");
        }, UPDATE_TIMEOUT_MS);
    }

    private List<String> getAllowedEnabledProviders() {
        List<String> providers = new ArrayList<>();
        if (locationManager == null) {
            return providers;
        }

        boolean fineGranted = ContextCompat.checkSelfPermission(
                activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        boolean coarseGranted = ContextCompat.checkSelfPermission(
                activity, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;

        try {
            for (String provider : locationManager.getProviders(true)) {
                if (!fineGranted && coarseGranted && LocationManager.GPS_PROVIDER.equals(provider)) {
                    continue;
                }
                providers.add(provider);
            }
        } catch (SecurityException ignored) {
            return new ArrayList<>();
        }

        providers.sort((left, right) -> Integer.compare(providerPriority(left), providerPriority(right)));
        return providers;
    }

    private Location findBestRecentLocation(List<String> providers) {
        List<Location> candidates = new ArrayList<>();
        long now = System.currentTimeMillis();
        for (String provider : providers) {
            try {
                Location location = locationManager.getLastKnownLocation(provider);
                if (!isUsableLocation(location)) {
                    continue;
                }
                long age = location.getTime() > 0L ? Math.max(0L, now - location.getTime()) : Long.MAX_VALUE;
                if (age <= MAX_LAST_KNOWN_AGE_MS) {
                    candidates.add(location);
                }
            } catch (SecurityException ignored) {
                return null;
            } catch (Exception ignored) {
                // Ignorar proveedores individuales defectuosos.
            }
        }

        return candidates.stream()
                .min(Comparator
                        .comparingLong(this::locationAge)
                        .thenComparingDouble(this::locationAccuracy))
                .orElse(null);
    }

    private long locationAge(Location location) {
        long time = location != null ? location.getTime() : 0L;
        if (time <= 0L) {
            return Long.MAX_VALUE;
        }
        return Math.max(0L, System.currentTimeMillis() - time);
    }

    private double locationAccuracy(Location location) {
        if (location == null || !location.hasAccuracy()) {
            return Double.MAX_VALUE;
        }
        return location.getAccuracy();
    }

    private int providerPriority(String provider) {
        if (LocationManager.NETWORK_PROVIDER.equals(provider)) {
            return 0;
        }
        if (LocationManager.GPS_PROVIDER.equals(provider)) {
            return 1;
        }
        if (LocationManager.PASSIVE_PROVIDER.equals(provider)) {
            return 2;
        }
        return 3;
    }

    private boolean hasAnyLocationPermission() {
        return ContextCompat.checkSelfPermission(
                activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                || ContextCompat.checkSelfPermission(
                activity, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean isUsableLocation(Location location) {
        if (location == null) {
            return false;
        }
        double lat = location.getLatitude();
        double lon = location.getLongitude();
        return !Double.isNaN(lat)
                && !Double.isNaN(lon)
                && !Double.isInfinite(lat)
                && !Double.isInfinite(lon)
                && lat >= -90.0d
                && lat <= 90.0d
                && lon >= -180.0d
                && lon <= 180.0d;
    }

    private void deliverSuccess(@NonNull Location location) {
        Callback callback = pendingCallback;
        clearActiveRequest();
        pendingCallback = null;
        requestInFlight = false;
        if (callback == null) {
            return;
        }
        callback.onLocationReady(new CapturedLocation(location.getLatitude(), location.getLongitude()));
    }

    private void deliverError(@NonNull String message) {
        Callback callback = pendingCallback;
        clearActiveRequest();
        pendingCallback = null;
        requestInFlight = false;
        if (callback == null) {
            return;
        }
        callback.onLocationError(message);
    }

    private void clearActiveRequest() {
        mainHandler.removeCallbacksAndMessages(null);
        if (locationManager != null && activeListener != null) {
            try {
                locationManager.removeUpdates(activeListener);
            } catch (Exception ignored) {
                // Sin acción adicional.
            }
        }
        activeListener = null;
    }
}
