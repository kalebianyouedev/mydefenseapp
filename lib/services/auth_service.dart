import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thin wrapper around Firebase Auth used by the Login / Signup screens.
///
/// All methods throw an [AuthException] with a message already translated
/// for display in a SnackBar (see [_mapFirebaseError]).
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  User? get currentUser => _auth.currentUser;

  /// Emits whenever the signed-in user changes (login, logout, token refresh).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// google_sign_in and sign_in_with_apple have no Windows/Linux
  /// implementation: guard against calling them there.
  bool get _desktopUnsupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (_desktopUnsupported) {
      throw AuthException(
          "La connexion Google n'est pas disponible sur cette plateforme.");
    }
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// Uses Apple's native authorization sheet, then exchanges the Apple
  /// credential for a Firebase credential. Requires the "Apple" sign-in
  /// provider to be enabled in the Firebase console.
  Future<UserCredential> signInWithApple() async {
    if (_desktopUnsupported) {
      throw AuthException(
          "La connexion Apple n'est pas disponible sur cette plateforme.");
    }
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((e) => e != null && e.isNotEmpty).join(' ');
      if (fullName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(fullName);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        rethrow;
      }
      throw AuthException("Apple sign-in failed. Please try again.");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_desktopUnsupported) return;
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore: user may never have signed in with Google.
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'This email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled yet.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
