import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'services/auth_service.dart';
import 'session_gate.dart';
import 'signup_screen.dart';
import 'widgets/auth_widgets.dart';

/// Login page (distinct from the Signup page).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToSignup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  // Vérifie aussi que le compte n'a pas été bloqué par l'administrateur.
  void _goToHome() => enterApp(context);

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAuthSnack(context, 'Please fill in both fields.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthService.instance
          .signInWithEmail(email: email, password: password);
      if (!mounted) return;
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      showAuthSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (!mounted || credential == null) return;
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      showAuthSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitApple() async {
    setState(() => _isSubmitting = true);
    try {
      await AuthService.instance.signInWithApple();
      if (!mounted) return;
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      showAuthSnack(context, e.message);
    } on SignInWithAppleAuthorizationException catch (_) {
      // User cancelled the Apple sheet, nothing to show.
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAuthSnack(context, 'Enter your email address first.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      showAuthSnack(context, 'Password reset email sent to $email.');
    } on AuthException catch (e) {
      if (!mounted) return;
      showAuthSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              AuthTopBar(
                onContinue: () =>
                    showAuthSnack(context, 'Coming soon'),
              ),
              Expanded(
                child: AuthCenteredBody(
                  children: [
                    const AuthLogo(),
                    const SizedBox(height: 20),
                    Text(
                      'Login',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: authInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to access your account and discover events',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        color: authMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthTabSwitch(
                      isLogin: true,
                      onTapInscription: _goToSignup,
                      onTapConnexion: () {},
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      controller: _emailController,
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSubmitting ? null : _forgotPassword,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: authInk,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AuthPrimaryButton(
                      label: _isSubmitting ? 'Logging in...' : 'Log in',
                      icon: Icons.login_rounded,
                      onPressed: _isSubmitting ? () {} : _submitLogin,
                    ),
                    const SizedBox(height: 20),
                    const AuthOrDivider(),
                    const SizedBox(height: 14),
                    Text(
                      'Log in with',
                      textAlign: TextAlign.center,
                      style:
                          GoogleFonts.nunito(fontSize: 13, color: authMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AuthSocialButton(
                            label: 'Google',
                            icon: googleGlyph(),
                            onTap: _isSubmitting ? () {} : _submitGoogle,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AuthSocialButton(
                            label: 'Apple',
                            icon: appleGlyph(),
                            onTap: _isSubmitting ? () {} : _submitApple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: authMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: _goToSignup,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: authPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
