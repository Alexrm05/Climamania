package com.example.climamaniaapp;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.drawerlayout.widget.DrawerLayout;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

public class BaseActivity extends AppCompatActivity {

    private static boolean pendingBodyEnterAnimation = false;
    private SwipeRefreshLayout globalSwipeRefresh;
    private boolean globalRefreshEnabled = true;
    private final Runnable forceStopRefreshRunnable = () -> {
        if (globalSwipeRefresh != null && globalSwipeRefresh.isRefreshing()) {
            globalSwipeRefresh.setRefreshing(false);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    protected void setupBottomBar() {
        View navCalendar = safeFind("navCalendar", "btnCalendarBar");
        View navHome     = safeFind("navHome", "btnHomeBar");
        View navRatings  = safeFind("navRatings", "btnRatingsBar");
        View navAdicionales = safeFind("navAdicionales", "btnAdicionalesBar");
        View navWeb      = safeFind("navWeb", "btnWebBar");
        ImageView iconCalendar = findViewById(R.id.btnCalendarBar);
        ImageView iconHome = findViewById(R.id.btnHomeBar);
        ImageView iconRatings = findViewById(R.id.btnRatingsBar);
        ImageView iconAdicionales = findViewById(R.id.btnAdicionalesBar);
        ImageView iconWeb = findViewById(R.id.btnWebBar);
        View btnRefresh = findViewById(R.id.btnRefresh);
        TextView labelCalendar = findViewById(R.id.txtCalendarBar);
        TextView labelHome = findViewById(R.id.txtHomeBar);
        TextView labelRatings = findViewById(R.id.txtRatingsBar);
        TextView labelAdicionales = findViewById(R.id.txtAdicionalesBar);
        TextView labelWeb = findViewById(R.id.txtWebBar);
        View btnDrawer   = findViewById(R.id.btnDrawer);
        DrawerLayout drawerLayout = findViewById(R.id.drawerLayout);
        View baseRoot = findViewById(R.id.baseRoot);
        globalSwipeRefresh = findViewById(R.id.globalSwipeRefresh);

        applyBottomBarState(navCalendar, navHome, navRatings, navAdicionales, navWeb,
            iconCalendar, iconHome, iconRatings, iconAdicionales, iconWeb,
            labelCalendar, labelHome, labelRatings, labelAdicionales, labelWeb);

        if (navCalendar != null) {
            navCalendar.setClickable(true);
            navCalendar.setOnClickListener(this::onClick);
        }


        if (navHome != null) {
            navHome.setClickable(true);
            navHome.setOnClickListener(v -> {
                if (!(this instanceof MainActivity)) {
                    startActivity(new Intent(this, MainActivity.class));
                    applyTransition(android.R.anim.fade_in, android.R.anim.fade_out);
                }
            });
        }

        if (navRatings != null) {
            navRatings.setClickable(true);
            navRatings.setOnClickListener(v -> {
                if (!(this instanceof ValoracionActivity)) {
                    startActivity(new Intent(this, ValoracionActivity.class));
                    applyTransition(android.R.anim.fade_in, android.R.anim.fade_out);
                }
            });
        }

        if (navAdicionales != null) {
            navAdicionales.setClickable(true);
            navAdicionales.setOnClickListener(v -> {
                if (!(this instanceof AdicionalesPresupuestoActivity)) {
                    startActivity(new Intent(this, AdicionalesPresupuestoActivity.class));
                    applyTransition(android.R.anim.fade_in, android.R.anim.fade_out);
                }
            });
        }

        if (navWeb != null) {
            navWeb.setClickable(true);
            navWeb.setOnClickListener(v -> {
                Intent intent = new Intent(BaseActivity.this, WebViewActivity.class);
                startActivity(intent);
                applyTransition(android.R.anim.slide_in_left, android.R.anim.fade_out);
            });
        }

        if (globalSwipeRefresh != null) {
            globalSwipeRefresh.setColorSchemeResources(R.color.colorPrimary, R.color.colorPrimaryDark);
            globalSwipeRefresh.setOnRefreshListener(this::triggerGlobalRefresh);
            globalSwipeRefresh.setOnChildScrollUpCallback((parent, child) -> {
                View content = findViewById(R.id.contentFrame);
                return canAnyChildScrollUp(content);
            });
            globalSwipeRefresh.removeCallbacks(forceStopRefreshRunnable);
            globalSwipeRefresh.setRefreshing(false);
            globalSwipeRefresh.setEnabled(globalRefreshEnabled);
            // Evita que Android restaure un estado "refreshing" atascado tras recreate().
            globalSwipeRefresh.post(() -> {
                if (globalSwipeRefresh != null && globalSwipeRefresh.isRefreshing()) {
                    globalSwipeRefresh.setRefreshing(false);
                }
            });
        }
        if (btnRefresh != null) {
            btnRefresh.setOnClickListener(v -> triggerGlobalRefresh());
        }

        if (baseRoot != null) {
            int baseLeft = baseRoot.getPaddingLeft();
            int baseTop = baseRoot.getPaddingTop();
            int baseRight = baseRoot.getPaddingRight();
            int baseBottom = baseRoot.getPaddingBottom();

            ViewCompat.setOnApplyWindowInsetsListener(baseRoot, (v, insets) -> {
                int bottomInset = insets.getInsets(WindowInsetsCompat.Type.systemBars()).bottom;
                v.setPadding(baseLeft, baseTop, baseRight, baseBottom + bottomInset);
                return insets;
            });
        }

        // Configuración del menú hamburguesa
        if (btnDrawer != null && drawerLayout != null) {
            btnDrawer.setOnClickListener(v ->
                    drawerLayout.openDrawer(androidx.core.view.GravityCompat.START));
        }

        // Rellenar nombre de usuario en el menú lateral
        View drawerUserView = findViewById(R.id.drawerUser);
        if (drawerUserView instanceof android.widget.TextView) {
            SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
            String nombre = UiText.sanitizeDbValue(prefs.getString("nombre", ""));
            String usuario = UiText.sanitizeDbValue(prefs.getString("usuario", ""));
            String displayName;
            if (nombre != null && !nombre.trim().isEmpty()) {
                displayName = nombre.trim();
            } else if (usuario != null && !usuario.trim().isEmpty()) {
                displayName = usuario.trim();
            } else {
                displayName = "Instalador";
            }
            ((android.widget.TextView) drawerUserView)
                    .setText("Hola, " + displayName);
        }

        // Opciones del menú lateral
        if (drawerLayout != null) {
            View menuHome = findViewById(R.id.menuHome);
            View menuCalendar = findViewById(R.id.menuCalendar);
            View menuSearch = findViewById(R.id.menuSearch);
            View menuAdicionales = findViewById(R.id.menuAdicionales);
            View menuWeb = findViewById(R.id.menuWeb);
            View menuLogout = findViewById(R.id.menuLogout);

            if (menuHome != null) {
                menuHome.setOnClickListener(v -> {
                    drawerLayout.closeDrawers();
                    if (!(this instanceof MainActivity)) {
                        startActivity(new Intent(this, MainActivity.class));
                    }
                });
            }

            if (menuCalendar != null) {
                menuCalendar.setOnClickListener(v -> {
                    drawerLayout.closeDrawers();
                    if (!(this instanceof CalendarActivity)) {
                        startActivity(new Intent(this, CalendarActivity.class));
                    }
                });
            }

            if (menuSearch != null) {
                menuSearch.setOnClickListener(v -> {
                    drawerLayout.closeDrawers();
                    if (!(this instanceof SearchEventsActivity)) {
                        startActivity(new Intent(this, SearchEventsActivity.class));
                    }
                });
            }

            if (menuAdicionales != null) {
                menuAdicionales.setOnClickListener(v -> {
                    drawerLayout.closeDrawers();
                    if (!(this instanceof AdicionalesPresupuestoActivity)) {
                        startActivity(new Intent(this, AdicionalesPresupuestoActivity.class));
                    }
                });
            }

            if (menuWeb != null) {
                menuWeb.setOnClickListener(v -> {
                    drawerLayout.closeDrawers();
                    if (!(this instanceof WebViewActivity)) {
                        startActivity(new Intent(this, WebViewActivity.class));
                    }
                });
            }

            if (menuLogout != null) {
                menuLogout.setOnClickListener(v -> {
                    drawerLayout.closeDrawers();
                    SharedPreferences prefs = getSharedPreferences("climamania_prefs", MODE_PRIVATE);
                    prefs.edit().clear().apply();
                    Intent intent = new Intent(this, LoginActivity.class);
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                    startActivity(intent);
                });
            }
        }
    }

    private View safeFind(String primaryIdName, String fallbackIdName) {
        int idPrimary  = getResources().getIdentifier(primaryIdName, "id", getPackageName());
        int idFallback = getResources().getIdentifier(fallbackIdName, "id", getPackageName());
        View v = (idPrimary != 0) ? findViewById(idPrimary) : null;
        if (v == null && idFallback != 0) v = findViewById(idFallback);
        return v;
    }

    private void onClick(View v) {
        if (!(this instanceof CalendarActivity)) {
            Intent intent = new Intent(this, CalendarActivity.class);
            startActivity(intent);
            applyTransition(android.R.anim.slide_in_left, android.R.anim.fade_out);
        }
    }

    private void applyBottomBarState(
            View navCalendar,
            View navHome,
            View navRatings,
            View navAdicionales,
            View navWeb,
            ImageView iconCalendar,
            ImageView iconHome,
            ImageView iconRatings,
            ImageView iconAdicionales,
            ImageView iconWeb,
            TextView labelCalendar,
            TextView labelHome,
            TextView labelRatings,
            TextView labelAdicionales,
            TextView labelWeb
    ) {
        boolean isCalendar = this instanceof CalendarActivity;
        boolean isHome = this instanceof MainActivity;
        boolean isRatings = this instanceof ValoracionActivity;
        boolean isAdicionales = this instanceof AdicionalesPresupuestoActivity
                || this instanceof PresupuestoInstaladorDetalleActivity;
        boolean isWeb = this instanceof WebViewActivity;

        int activeColor = ContextCompat.getColor(this, R.color.colorPrimary);
        int inactiveColor = ContextCompat.getColor(this, R.color.footerInactive);

        setFooterItemState(navCalendar, iconCalendar, labelCalendar, isCalendar, activeColor, inactiveColor);
        setFooterItemState(navHome, iconHome, labelHome, isHome, activeColor, inactiveColor);
        setFooterItemState(navRatings, iconRatings, labelRatings, isRatings, activeColor, inactiveColor);
        setFooterItemState(navAdicionales, iconAdicionales, labelAdicionales, isAdicionales, activeColor, inactiveColor);
        setFooterItemState(navWeb, iconWeb, labelWeb, isWeb, activeColor, inactiveColor);
    }

    private void setFooterItemState(
            View container,
            ImageView icon,
            TextView label,
            boolean active,
            int activeColor,
            int inactiveColor
    ) {
        if (container != null) {
            container.setBackgroundResource(active
                    ? R.drawable.bg_footer_item_active
                    : R.drawable.bg_footer_item_inactive);
            float targetScale = active ? 1.04f : 1.0f;
            float targetAlpha = active ? 1.0f : 0.92f;
            container.animate()
                    .scaleX(targetScale)
                    .scaleY(targetScale)
                    .alpha(targetAlpha)
                    .setDuration(160)
                    .start();
        }
        if (icon != null) {
            icon.setColorFilter(active ? activeColor : inactiveColor);
            icon.setAlpha(active ? 1f : 0.9f);
        }
        if (label != null) {
            label.setTextColor(active ? activeColor : inactiveColor);
        }
    }

    @SuppressWarnings("deprecation")
    protected void applyTransition(int enterAnim, int exitAnim) {
        pendingBodyEnterAnimation = true;
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0);
        } else {
            overridePendingTransition(0, 0);
        }
    }

    @Override
    protected void onPostResume() {
        super.onPostResume();
        if (!pendingBodyEnterAnimation) return;

        View contentFrame = findViewById(R.id.contentFrame);
        if (contentFrame == null) return;

        pendingBodyEnterAnimation = false;
        contentFrame.setTranslationX(dp(18));
        contentFrame.setAlpha(0.0f);
        contentFrame.animate()
                .translationX(0f)
                .alpha(1.0f)
                .setDuration(220)
                .start();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void triggerGlobalRefresh() {
        if (!globalRefreshEnabled) {
            setGlobalRefreshing(false);
            return;
        }
        setGlobalRefreshing(true);
        scheduleGlobalRefreshFailsafe();
        onGlobalRefreshRequested();
    }

    protected void onGlobalRefreshRequested() {
        // En el flujo por defecto solo recreamos pantalla: no dejamos spinner en curso.
        setGlobalRefreshing(false);
        recreate();
    }

    protected void setGlobalRefreshing(boolean refreshing) {
        if (globalSwipeRefresh != null) {
            if (!refreshing) {
                globalSwipeRefresh.removeCallbacks(forceStopRefreshRunnable);
            }
            globalSwipeRefresh.setRefreshing(refreshing);
        }
    }

    protected void setGlobalRefreshEnabled(boolean enabled) {
        globalRefreshEnabled = enabled;
        if (globalSwipeRefresh != null) {
            globalSwipeRefresh.setEnabled(enabled);
            if (!enabled) {
                globalSwipeRefresh.removeCallbacks(forceStopRefreshRunnable);
                globalSwipeRefresh.setRefreshing(false);
            }
        }
    }

    private void scheduleGlobalRefreshFailsafe() {
        if (globalSwipeRefresh == null) {
            return;
        }
        globalSwipeRefresh.removeCallbacks(forceStopRefreshRunnable);
        globalSwipeRefresh.postDelayed(forceStopRefreshRunnable, 12000L);
    }

    private boolean canAnyChildScrollUp(View root) {
        if (root == null || root.getVisibility() != View.VISIBLE) {
            return false;
        }
        if (root.canScrollVertically(-1)) {
            return true;
        }
        if (root instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) root;
            for (int i = 0; i < group.getChildCount(); i++) {
                if (canAnyChildScrollUp(group.getChildAt(i))) {
                    return true;
                }
            }
        }
        return false;
    }

    @Override
    protected void onDestroy() {
        if (globalSwipeRefresh != null) {
            globalSwipeRefresh.removeCallbacks(forceStopRefreshRunnable);
        }
        super.onDestroy();
    }
}
