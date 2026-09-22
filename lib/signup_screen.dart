import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'services/auth_service.dart';
import 'widgets/auth_widgets.dart';

/// Signup page (distinct from the Login page).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _submitSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showAuthSnack(context, 'Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      showAuthSnack(context, 'Passwords do not match.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthService.instance.signUpWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
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
                      'Sign Up',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: authInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account to book your tickets and experience every event',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: authMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthTabSwitch(
                      isLogin: false,
                      onTapInscription: () {},
                      onTapConnexion: _goToLogin,
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      controller: _nameController,
                      label: 'Full name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _confirmController,
                      label: 'Confirm password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirm,
                      onToggleObscure: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 18),
                    AuthPrimaryButton(
                      label: _isSubmitting
                          ? 'Creating account...'
                          : 'Create my account',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: _isSubmitting ? () {} : _submitSignup,
                    ),
                    const SizedBox(height: 20),
                    const AuthOrDivider(),
                    const SizedBox(height: 14),
                    Text(
                      'Or sign up with',
                      textAlign: TextAlign.center,
                      style:
                          GoogleFonts.poppins(fontSize: 13, color: authMuted),
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
                          'Already have an account?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: authMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: _goToLogin,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Log in',
                            style: GoogleFonts.poppins(
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
