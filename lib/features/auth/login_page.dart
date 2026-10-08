import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import 'auth_controller.dart';
import 'signup_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final language = ref.read(languageControllerProvider);
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).signIn(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      // Navigation is handled by AuthGate reacting to the auth state stream.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyAuthErrorMessage(e, language)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    final language = ref.read(languageControllerProvider);
    setState(() => _isGoogleLoading = true);
    try {
      final cred = await ref.read(authControllerProvider).signInWithGoogle();
      if (cred == null) {
        // User cancelled Google sign-in
        return;
      }
      // AuthGate will handle navigation automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyAuthErrorMessage(e, language)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final language = ref.read(languageControllerProvider);
    final emailController = TextEditingController(text: _emailController.text.trim());
    final recoveryKeyController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int selectedMethod = 0; // 0 = Recovery Key, 1 = Email Link
    bool isResetting = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.tr(language, 'reset_password'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Method selector tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDialogState(() => selectedMethod = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedMethod == 0 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppStrings.tr(language, 'recovery_method_key'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedMethod == 0 ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDialogState(() => selectedMethod = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedMethod == 1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppStrings.tr(language, 'recovery_method_email'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedMethod == 1 ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (selectedMethod == 0) ...[
                    // Recovery Key / In-App Reset View
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.tr(language, 'recovery_key_desc'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr(language, 'email_address'),
                        hintText: 'name@example.com',
                        prefixIcon: const Icon(Icons.alternate_email, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: recoveryKeyController,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr(language, 'recovery_key'),
                        hintText: AppStrings.tr(language, 'recovery_key_hint'),
                        prefixIcon: const Icon(Icons.key_outlined, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr(language, 'new_password'),
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr(language, 'confirm_new_password'),
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ] else ...[
                    // Email Reset Link View
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.tr(language, 'reset_password_desc'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'name@company.com',
                        labelText: AppStrings.tr(language, 'email_address'),
                        prefixIcon: const Icon(Icons.alternate_email, size: 20),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
              child: Text(AppStrings.tr(language, 'cancel')),
            ),
            FilledButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.tr(language, 'email_address'))),
                        );
                        return;
                      }

                    setDialogState(() => isResetting = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogCtx);
                    if (selectedMethod == 0) {
                      // In-App Key Reset
                      final key = recoveryKeyController.text.trim();
                      final newPass = newPasswordController.text.trim();
                      final confirmPass = confirmPasswordController.text.trim();

                      if (key.isEmpty) {
                        setDialogState(() => isResetting = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text(AppStrings.tr(language, 'enter_recovery_key'))),
                        );
                        return;
                      }
                      if (newPass.length < 6) {
                        setDialogState(() => isResetting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.tr(language, 'password_min_length')),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                        return;
                      }
                      if (newPass != confirmPass) {
                        setDialogState(() => isResetting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.tr(language, 'passwords_do_not_match')),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                        return;
                      }

                      try {
                        await ref.read(authControllerProvider).resetPasswordWithRecoveryKey(
                              email: email,
                              recoveryKey: key,
                              newPassword: newPass,
                            );
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.tr(language, 'password_reset_success')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(getFriendlyAuthErrorMessage(e, language)),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      // Email link reset
                      try {
                        await ref.read(authControllerProvider).sendPasswordResetEmail(email);
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.tr(language, 'reset_email_sent')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(getFriendlyAuthErrorMessage(e, language)),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
              child: isResetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      selectedMethod == 0
                          ? AppStrings.tr(language, 'reset_password')
                          : AppStrings.tr(language, 'send_reset_link'),
                    ),
            ),
          ],
        ),
      ),
    ).then((_) {
      emailController.dispose();
      recoveryKeyController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Widget _buildLabelRow(String label, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.tr(language, 'app_title'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.tr(language, 'manage_shared_expenses'),
                      style: TextStyle(
                        fontSize: 14,
                        color: onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    _buildLabelRow(AppStrings.tr(language, 'email_address')),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'name@company.com',
                        hintStyle: TextStyle(color: onSurfaceVariant),
                        prefixIcon: Icon(Icons.alternate_email, color: onSurfaceVariant),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 24),
                    
                    _buildLabelRow(
                      AppStrings.tr(language, 'password'),
                      action: GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: Text(
                          AppStrings.tr(language, 'forgot_password'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: onSurfaceVariant),
                        prefixIcon: Icon(Icons.lock_outline, color: onSurfaceVariant),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: onSurfaceVariant),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 32),
                    
                    FilledButton(
                      onPressed: (_isLoading || _isGoogleLoading) ? null : _login,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(AppStrings.tr(language, 'login'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),

                    // OR Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            AppStrings.tr(language, 'or_divider'),
                            style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google Sign-In Button
                    OutlinedButton(
                      onPressed: (_isLoading || _isGoogleLoading) ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        backgroundColor: Theme.of(context).cardColor,
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  AppStrings.tr(language, 'continue_with_google'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${AppStrings.tr(language, 'dont_have_account').split('?').first}? ",
                          style: TextStyle(color: onSurfaceVariant),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignupPage()),
                            );
                          },
                          child: Text(
                            AppStrings.tr(language, 'signup'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
