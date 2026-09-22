import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/stockimg_config.dart';

class StockImgException implements Exception {
  final String message;
  StockImgException(this.message);

  @override
  String toString() => message;
}

/// Minimal client for the StockImg file storage API
/// (https://storage.mrsergio.dev/docs). Handles images and PDFs only —
/// Firebase Auth/Firestore keep managing accounts and app data; the URL
/// returned here is stored as a plain string field, exactly like a
/// Firebase Storage download URL would be.
class StockImgClient {
  StockImgClient._();
  static final StockImgClient instance = StockImgClient._();

  static const _timeout = Duration(seconds: 30);

  String get _baseUrl => StockImgConfig.baseUrl;
  Map<String, String> get _headers =>
      {'Authorization': 'Bearer ${StockImgConfig.apiKey}'};

  /// Sends a file (image or PDF, 5MB/10MB limits) and returns its public
  /// URL.
  Future<String> uploadFile(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/v1/files'),
    )
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed =
        await request.send().timeout(const Duration(seconds: 90));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 201) {
      throw StockImgException(_mapError(streamed.statusCode, body));
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['data'] as Map<String, dynamic>)['url'] as String;
  }

  Future<List<Map<String, dynamic>>> listFiles() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/v1/files'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StockImgException(_mapError(response.statusCode, response.body));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteFile(int id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/api/v1/files/$id'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 204) {
      throw StockImgException(_mapError(response.statusCode, response.body));
    }
  }

  String _mapError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Clé API StockImg manquante ou invalide.';
      case 403:
        return 'Ce fichier ne vous appartient pas.';
      case 422:
        return 'Fichier refusé (type non autorisé, trop volumineux ou quota dépassé).';
      case 429:
        return 'Trop de requêtes, réessayez dans une minute.';
      default:
        return 'Échec de l\'opération StockImg ($statusCode).';
    }
  }
}
