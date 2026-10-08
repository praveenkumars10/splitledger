import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import 'auth_controller.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  void _loginWithGoogle() async {
    final language = ref.read(languageControllerProvider);
    setState(() => _isGoogleLoading = true);
    try {
      final cred = await ref.read(authControllerProvider).signInWithGoogle();
      if (cred == null) {
        return;
      }
      // AuthGate handles navigation automatically
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

  void _signup() async {
    final language = ref.read(languageControllerProvider);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr(language, 'email_address'))),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(language, 'password_min_length')),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(language, 'passwords_do_not_match')),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final recoveryKey = _recoveryKeyController.text.trim();

    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authControllerProvider).signUp(
            name: name,
            email: email,
            password: password,
            recoveryKey: recoveryKey.isNotEmpty ? recoveryKey : null,
          );
      // Store the display name so household members show a friendly name.
      await user.user?.updateDisplayName(name);

      if (mounted) {
        // Return to AuthGate which will route to household setup.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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

  Widget _buildLabelRow(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
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
                      AppStrings.tr(language, 'create_account'),
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
                    
                    _buildLabelRow(AppStrings.tr(language, 'full_name')),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'John Doe',
                        hintStyle: TextStyle(color: onSurfaceVariant),
                        prefixIcon: Icon(Icons.person_outline, color: onSurfaceVariant),
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
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 16),
                    
                    _buildLabelRow(AppStrings.tr(language, 'password')),
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
                    ),
                    const SizedBox(height: 16),

                    _buildLabelRow(AppStrings.tr(language, 'confirm_password')),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: onSurfaceVariant),
                        prefixIcon: Icon(Icons.lock_outline, color: onSurfaceVariant),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: onSurfaceVariant),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                      obscureText: _obscureConfirmPassword,
                      onSubmitted: (_) => _signup(),
                    ),
                    const SizedBox(height: 16),

                    _buildLabelRow(AppStrings.tr(language, 'recovery_key')),
                    TextField(
                      controller: _recoveryKeyController,
                      decoration: InputDecoration(
                        hintText: AppStrings.tr(language, 'recovery_key_hint'),
                        hintStyle: TextStyle(color: onSurfaceVariant),
                        prefixIcon: Icon(Icons.key_outlined, color: onSurfaceVariant),
                        helperText: AppStrings.tr(language, 'recovery_key_desc'),
                        helperMaxLines: 2,
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
                    ),
                    const SizedBox(height: 32),
                    
                    FilledButton(
                      onPressed: (_isLoading || _isGoogleLoading) ? null : _signup,
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
                          : Text(AppStrings.tr(language, 'signup'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          "${AppStrings.tr(language, 'already_have_account').split('?').first}? ",
                          style: TextStyle(color: onSurfaceVariant),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            AppStrings.tr(language, 'login'),
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
