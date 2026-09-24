import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Components shared between the Login screen and the Signup screen
/// so both pages stay visually identical.
/// Deliberately flat style: no shadow, no gradient.
// Palette Ça Bouge Où ? : bleu nuit de la marque (actions, sélection),
// rouge pour les boutons de réservation, vert pour les prix, ambre pour
// les boosts.
const authPrimary = Color(0xFF1E3A8A);
const authAccent = Color(0xFFDC2626);
const authSuccess = Color(0xFF16A34A);
const authBoost = Color(0xFFF5B335);
const authPrimarySoft = Color(0xFFEAF0FB);
const authInk = Color(0xFF0F172A);
const authMuted = Color(0xFF64748B);
const authBorder = Color(0xFFE2E8F0);

void showAuthSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Top bar: language selector + "Continue" button.
class AuthTopBar extends StatelessWidget {
  final VoidCallback onContinue;

  const AuthTopBar({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: authBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇬🇧', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'EN',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: authInk,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 16, color: authMuted),
            ],
          ),
        ),
        TextButton(
          onPressed: onContinue,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continue',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: authInk,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward, size: 16, color: authInk),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        height: 64,
        errorBuilder: (context, error, stackTrace) => Text(
          'Where the party is',
          style: GoogleFonts.nunito(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: authPrimary,
          ),
        ),
      ),
    );
  }
}

/// Signup / Login tabs that navigate to the corresponding screen.
class AuthTabSwitch extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onTapInscription;
  final VoidCallback onTapConnexion;

  const AuthTabSwitch({
    super.key,
    required this.isLogin,
    required this.onTapInscription,
    required this.onTapConnexion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'Sign Up',
              icon: Icons.person_add_alt_outlined,
              active: !isLogin,
              onTap: onTapInscription,
            ),
          ),
          Expanded(
            child: _Tab(
              label: 'Login',
              icon: Icons.lock_outline,
              active: isLogin,
              onTap: onTapConnexion,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: active ? authPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? Colors.white : authMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : authMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple input field: thin border, no shadow.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.nunito(fontSize: 14, color: authInk),
      cursorColor: authPrimary,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.nunito(fontSize: 14, color: authMuted),
        prefixIcon: Icon(icon, size: 20, color: authMuted),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: authMuted,
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: authBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: authBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: authPrimary, width: 1.4),
        ),
      ),
    );
  }
}

/// Main (CTA) button, flat.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: authPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Social login button (Google / Apple), flat.
class AuthSocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const AuthSocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: authBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: authInk,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: authBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: GoogleFonts.nunito(fontSize: 13, color: authMuted),
          ),
        ),
        const Expanded(child: Divider(color: authBorder, thickness: 1)),
      ],
    );
  }
}

Widget googleGlyph() => Text(
      'G',
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF4285F4),
      ),
    );

Widget appleGlyph() => const Icon(Icons.apple, size: 20, color: Colors.black);

/// Column vertically centered in the available space, which becomes
/// scrollable again if the content overflows (small screen / open keyboard).
class AuthCenteredBody extends StatelessWidget {
  final List<Widget> children;

  const AuthCenteredBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}
