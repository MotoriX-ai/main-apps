import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:motorix_phase2/motorix_phase2.dart';

import 'package:motorix_phase2/app/core/api_config.dart';

class RecipeRepository {
  RecipeRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get pipelineBaseUrl => ApiConfig.instance.baseUrl;

  Future<ExerciseRecipe> loadDemo() async {
    final raw =
        await rootBundle.loadString('assets/recipes/demo_knee_extension.json');
    return ExerciseRecipe.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<ExerciseRecipe?> importFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null) return null;
    final picked = result.files.single;
    final bytes = picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) {
      throw const FormatException('File recipe tidak dapat dibaca');
    }
    return ExerciseRecipe.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }

  Future<ExerciseRecipe> loadByCode(String value) async {
    final compact = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final code = compact.startsWith('MX') ? compact.substring(2) : compact;
    if (code.length != 8) {
      throw const FormatException(
          'Kode latihan harus berisi 8 karakter (contoh: MX-E44D3752).');
    }
    final targetCode = 'MX-$code';
    try {
      final response = await _client
          .get(Uri.parse('$pipelineBaseUrl/v1/recipes/code/$targetCode'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        throw const FormatException(
            'Kode latihan tidak ditemukan atau belum dipublikasikan dokter.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException(
            'Gagal mengunduh recipe (status: ${response.statusCode}). Periksa koneksi ke server.');
      }
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ExerciseRecipe.fromJson(json);
    } on http.ClientException {
      throw FormatException(
          'Tidak dapat terhubung ke $pipelineBaseUrl. Periksa koneksi internet atau server backend.');
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Gagal memuat recipe: $e');
    }
  }

  void dispose() => _client.close();
}
