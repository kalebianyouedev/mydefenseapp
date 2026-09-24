import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_prefs.dart';
import 'admin_service.dart';
import 'admin_shell.dart';
import 'admin_widgets.dart';

/// Connexion à l'espace administrateur Ça Bouge Où ?. Seuls les comptes
/// présents dans la collection `admins` peuvent entrer.
class AdminLoginScreen extends StatefulWidget {
  final String? initialError;

  const AdminLoginScreen({super.key, this.initialError});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _remember = false;
  bool _loading = false;
  late String? _error = widget.initialError;

  @override
  void initState() {
    super.initState();
    AdminPrefs.load().then((p) {
      if (!mounted) return;
      setState(() {
        _remember = p.remember;
        if (p.remember && p.email.isNotEmpty) _emailCtrl.text = p.email;
      });
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Saisissez votre email et votre mot de passe.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminService.instance.signIn(email, password);
      await AdminPrefs.save(AdminPrefs(remember: _remember, email: _remember ? email : ''));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const AdminShell(),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Vérifiez votre connexion internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Saisissez d'abord votre adresse email.");
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) adminToast(context, 'Email de réinitialisation envoyé à $email.');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  InputDecoration _decoration({String? hint, Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: adminText(14, color: AdminColors.muted),
    suffixIcon: suffix,
    filled: true,
    fillColor: AdminColors.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xFF8A9BC4), width: 2),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: adminText(14.5, weight: FontWeight.w500, color: AdminColors.ink),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 432),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 62,
                      errorBuilder: (_, _, _) => Text(
                        'Ça Bouge Où ?',
                        style: adminText(24, weight: FontWeight.w800, color: AdminColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Connexion',
                    textAlign: TextAlign.center,
                    style: adminText(21, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Connectez-vous avec votre email et votre mot de passe.',
                    textAlign: TextAlign.center,
                    style: adminText(14.5, color: AdminColors.muted),
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AdminColors.danger.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.danger.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: AdminColors.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!, style: adminText(13.5, color: AdminColors.danger)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _label('Adresse email'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    style: adminText(14.5),
                    decoration: _decoration(hint: 'vous@exemple.com'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _label('Mot de passe')),
                      // Hors du parcours clavier : Entrée ne doit déclencher que
                      // la connexion (sinon elle activait l'élément suivant).
                      ExcludeFocus(
                        child: InkWell(
                          onTap: _loading ? null : _forgotPassword,
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 1),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AdminColors.border)),
                            ),
                            child: Text('Mot de passe oublié ?', style: adminText(14.5, color: AdminColors.ink)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordCtrl,
                    focusNode: _passwordFocus,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: adminText(14.5),
                    decoration: _decoration(
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ExcludeFocus(
                          child: IconButton(
                            tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AdminColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ExcludeFocus(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _remember = !_remember),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _remember,
                              onChanged: (v) => setState(() => _remember = v ?? false),
                              activeColor: AdminColors.primary,
                              side: const BorderSide(color: AdminColors.border, width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Se souvenir de moi', style: adminText(14.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AdminColors.primary.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Text(
                              'Se connecter',
                              style: adminText(15, weight: FontWeight.w600, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text.rich(
                    TextSpan(
                      style: adminText(14.5, color: AdminColors.muted),
                      children: [
                        const TextSpan(text: 'Accès réservé aux '),
                        TextSpan(
                          text: 'administrateurs',
                          style: adminText(14.5, color: AdminColors.ink),
                        ),
                        const TextSpan(text: ' de la plateforme.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
