import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'login_controller.dart';

/// Pantalla de acceso. Réplica de `activity_login.xml` + `LoginActivity.java`.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LoginController(
        ctx.read<AuthRepository>(),
        ctx.read<SessionService>(),
      ),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = context.read<LoginController>();
    _userCtrl.text = controller.initialUsuario;
    _passCtrl.text = controller.initialPassword;
    _remember = controller.initialRemember;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _attemptLogin() async {
    final usuario = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (usuario.isEmpty || password.isEmpty) {
      _showMessage('Por favor, completa todos los campos');
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = context.read<LoginController>();
    final result = await controller.submit(
      usuario: usuario,
      password: password,
      remember: _remember,
    );
    if (!mounted) return;
    if (result.success) {
      // Sin SnackBar de bienvenida: tapaba la barra inferior y la pantalla de
      // Inicio ya saluda al usuario. Vamos directo a Inicio.
      context.go('/home');
    } else {
      _showMessage(result.error ?? 'Usuario o contraseña incorrectos');
    }
  }

  void _clearFields() {
    setState(() {
      _userCtrl.clear();
      _passCtrl.clear();
      _remember = false;
    });
    context.read<LoginController>().clearRemembered();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<LoginController>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: Image.asset(
                    'assets/images/climamania_logo.png',
                    height: 104,
                    fit: BoxFit.contain,
                  ),
                ),
                // Tarjeta de login
                Container(
                  decoration: AppDecorations.loginCard,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Acceso instaladores',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Introduce tus credenciales para continuar.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _inputField(
                        controller: _userCtrl,
                        hint: 'Identificador',
                        leadingIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _passwordField(),
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () =>
                            setState(() => _remember = !_remember),
                        borderRadius: AppRadius.brSm,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _remember,
                                  onChanged: (v) => setState(
                                      () => _remember = v ?? false),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Recordar usuario',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Botón Acceder en su propia línea, a todo el ancho.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _attemptLogin,
                          style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.brPill)),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Acceder'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: isLoading ? null : _clearFields,
                          child: Text(
                            'Limpiar campos',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: Text(
                          '¿Has olvidado la contraseña?',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    IconData? leadingIcon,
    TextInputAction? textInputAction,
  }) {
    return Container(
      height: 50,
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              textInputAction: textInputAction,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: AppDecorations.bareInput(
                hintText: hint,
                suffixIcon: suffix,
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField() {
    return _inputField(
      controller: _passCtrl,
      hint: 'Contraseña',
      leadingIcon: Icons.lock_outline,
      obscure: _obscure,
      suffix: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Image.asset(
            _obscure
                ? 'assets/images/ic_visibility_off.png'
                : 'assets/images/ic_visibility.png',
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
  }
}
