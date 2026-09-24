import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Préférences locales de l'app admin (fichier JSON sur le poste) :
/// « Se souvenir de moi » garde la session et pré-remplit l'email.
class AdminPrefs {
  final bool remember;
  final String email;

  const AdminPrefs({this.remember = false, this.email = ''});

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}admin_prefs.json');
  }

  static Future<AdminPrefs> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const AdminPrefs();
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return AdminPrefs(remember: map['remember'] as bool? ?? false, email: map['email'] as String? ?? '');
    } catch (_) {
      return const AdminPrefs();
    }
  }

  static Future<void> save(AdminPrefs prefs) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({'remember': prefs.remember, 'email': prefs.email}));
    } catch (_) {}
  }
}
