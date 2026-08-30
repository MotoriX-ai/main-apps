import 'package:flutter/foundation.dart';

class ApiServerPreset {
  const ApiServerPreset({
    required this.name,
    required this.url,
    required this.description,
  });

  final String name;
  final String url;
  final String description;
}

class ApiConfig extends ChangeNotifier {
  ApiConfig._();

  static final ApiConfig instance = ApiConfig._();

  static const String cloudRunUrl =
      'https://motorix-pipeline-api-1031020302062.asia-southeast1.run.app';
  static const String localHostUrl = 'http://127.0.0.1:8000';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000';

  static const List<ApiServerPreset> presets = [
    ApiServerPreset(
      name: 'Cloud Run (Live)',
      url: cloudRunUrl,
      description: 'Server cloud production Google Cloud Run',
    ),
    ApiServerPreset(
      name: 'Localhost (127.0.0.1)',
      url: localHostUrl,
      description: 'Server pipeline lokal pada port 8000 (iOS / Web / Mac)',
    ),
    ApiServerPreset(
      name: 'Android Emulator (10.0.2.2)',
      url: androidEmulatorUrl,
      description: 'Koneksi host dari Android Emulator',
    ),
  ];

  static const String _defaultBaseUrl = String.fromEnvironment(
    'PIPELINE_API_BASE_URL',
    defaultValue: kDebugMode ? localHostUrl : cloudRunUrl,
  );

  String _baseUrl = _defaultBaseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    var sanitized = url.trim();
    while (sanitized.endsWith('/')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    if (sanitized.isEmpty) {
      sanitized = cloudRunUrl;
    }
    if (_baseUrl != sanitized) {
      _baseUrl = sanitized;
      notifyListeners();
    }
  }

  void resetToDefault() {
    setBaseUrl(_defaultBaseUrl);
  }
}
